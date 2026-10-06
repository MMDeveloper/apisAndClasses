<?php

class floridaprepaid {

    private static array $requiredInfo = array(
        'authURL'          => false,
        'apiBaseURL'       => false,
        'clientID'         => false,
        'clientSecret'     => false,
        'fppPublicKeyPath' => false,
        'myPrivateKeyPath' => false
    );

    private static array $optionalInfo = array();

    private static array $pointers = array(
        'fppPublicKey' => false,
        'myPrivateKey' => false,
        'encryptor'    => false,
        'decryptor'    => false,
        'serializer'   => false
    );

    public static array $errors = array();

    private static $cachePrefix = 'floridaprepaid.';

    public static function init(array $initValues): bool {

        foreach ( $initValues as $k => $v ) {
            if (array_key_exists( $k, self::$requiredInfo ) === true) {
                self::$requiredInfo[$k] = $v;
            }
            else {
                self::$optionalInfo[$k] = $v;
            }
        }

        if (file_exists( self::$requiredInfo['fppPublicKeyPath'] ) === true) {
            self::$pointers['fppPublicKey'] = Silencenjoyer\Jwe\Keys\Key::fromContent( file_get_contents( self::$requiredInfo['fppPublicKeyPath'] ) );
            self::$pointers['encryptor']    = new Silencenjoyer\Jwe\Encryptors\Encryptor(
                new Silencenjoyer\Jwe\KeyEncapsulation\RsaKeyWrapper( self::$pointers['fppPublicKey'] ),
                new Silencenjoyer\Jwe\Ciphers\Factory\Aes256GcmFactory(),
            );

        }
        else {
            self::$errors[]                         = 'fppPublicKeyPath does not exist';
            self::$requiredInfo['fppPublicKeyPath'] = false;
        }

        if (file_exists( self::$requiredInfo['myPrivateKeyPath'] ) === true) {
            self::$pointers['myPrivateKey'] = Silencenjoyer\Jwe\Keys\Key::fromContent( file_get_contents( self::$requiredInfo['myPrivateKeyPath'] ) );
            self::$pointers['decryptor']    = new Silencenjoyer\Jwe\Decryptors\Decryptor(
                new Silencenjoyer\Jwe\KeyEncapsulation\RsaKeyUnwrapper( self::$pointers['myPrivateKey'] ),
                new Silencenjoyer\Jwe\Ciphers\Factory\Aes256GcmFactory(),
            );
        }
        else {
            self::$errors[]                         = 'myPrivateKeyPath does not exist';
            self::$requiredInfo['myPrivateKeyPath'] = false;
        }

        if (in_array( false, array_values( self::$requiredInfo ) ) === false) {
            self::$pointers['serializer'] = new Silencenjoyer\Jwe\Serializers\CompactSerializer();

            return true;
        }
        else {
            self::$errors[] = 'Missing required fields';
            return false;
        }
    }



    private static function getAccessToken(): mixed {

        $cacheID = self::$cachePrefix . 'api_accesstoken';

        if (cache::hasCache( $cacheID ) === false) {
            $headers = array(
                'Content-Type: application/x-www-form-urlencoded'
            );
            $params  = array(
                'grant_type' => 'client_credentials',
                'scope'      => 'mulesoft'
            );
            $options = array(
                CURLOPT_USERPWD => self::$requiredInfo['clientID'] . ':' . self::$requiredInfo['clientSecret']
            );

            $authResponse = curl::makeSingleRequest( 'POST', self::$requiredInfo['authURL'], $params, $headers, $options );

            if (intval( curl::$debugInfos['http_code'] ) === 200) {
                $authResponse               = json_decode( $authResponse, true );
                $authResponse['expires_in'] = intval( $authResponse['expires_in'] ) - 30;
                $authResponse['expires_in'] = max( $authResponse['expires_in'], 180 ); //sanity check

                cache::writeCache( $cacheID, $authResponse['access_token'], $authResponse['expires_in'] . ' seconds' );
                return $authResponse['access_token'];
            }
            else {
                self::$errors[] = 'Error getting OAUTH access token: ' . print_r( $authResponse, true );
                return false;
            }
        }
        else {
            return cache::getCache( $cacheID );
        }
    }



    public static function doAPICall(string $method, string $endpoint, array $jsonPayload = array(), array $additionalHeaders = array()): array {

        $return = array(
            'successState' => false,
            'errorMessage' => '',
            'data'         => null
        );

        $accessToken = self::getAccessToken();

        if ($accessToken === false) {
            $return['errorMessage'] = 'Error retrieving access token';
            return $return;
        }

        $headers = array(
            'Authorization: Bearer ' . $accessToken,
            'Accept: application/json',
            'alg: RSA-OAEP',
            'enc: A256GCM',
            'encryption: JWE',
            'client_id: ' . self::$requiredInfo['clientID'],
            'client_secret: ' . self::$requiredInfo['clientSecret']
        );

        $jwt        = Firebase\JWT\JWT::encode( $jsonPayload, self::$requiredInfo['clientSecret'], 'HS256' );
        $jwt        = json_encode( $jwt );
        $compactJwe = self::$pointers['serializer']->serialize( self::$pointers['encryptor']->encrypt( $jwt ) );

        $apiResponse = curl::makeSingleRequest( $method, self::$requiredInfo['apiBaseURL'] . $endpoint, array( 'jwe' => $compactJwe ), $headers );

        if (intval( curl::$debugInfos['http_code'] ) === 200) {
            $return['successState'] = true;

            $plaintext      = self::$pointers['decryptor']->decrypt( self::$pointers['serializer']->unserialize( $apiResponse ) );
            $decoded        = explode( '.', $plaintext );
            $plaintext      = json_decode( base64_decode( $decoded[1] ), true );
            $return['data'] = $plaintext;
        }
        else {
            $return['errorMessage'] = 'API Error: ' . print_r( $apiResponse, true );
        }

        return $return;
    }



}



?>