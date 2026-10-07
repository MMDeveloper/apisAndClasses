<?php

/**
 * This is a class for interacting with Florida PrePaid API
 * There are dependencies: 
 *      Silencenjoyer JWE (https://github.com/silencenjoyer/jwe/tree/main)
 *      FireBase JWT (https://github.com/googleapis/php-jwt)
 * @package FloridaPrePaid
 * @version 1.0
 */
class floridaprepaid {

    /**
     * required information, if any value remains falsed after init, sanity check fails
     * @var array
     */
    private static array $requiredInfo = array(
        'authURL'          => false,
        'apiBaseURL'       => false,
        'clientID'         => false,
        'clientSecret'     => false,
        'fppPublicKeyPath' => false,
        'myPrivateKeyPath' => false
    );

    /**
     * optional information for future use
     * @var array
     */
    private static array $optionalInfo = array();

    /**
     * array of pointers for 3rd party classes
     * @var array
     */
    private static array $pointers = array(
        'fppPublicKey' => false,
        'myPrivateKey' => false,
        'encryptor'    => false,
        'decryptor'    => false,
        'serializer'   => false
    );

    /**
     * growing list of error messages as they are encountered
     * @var array
     */
    public static array $errors = array();

    /**
     * namespacing memory cache keys for this class
     * @var string
     */
    private static string $cachePrefix = 'floridaprepaid.';

    /**
     * This is the init method which ingests the runtime configuration
     * @access public
     * @param array $initValues array of required and optional values in the keys=>vals format
     * @return bool
     */
    public static function init(array $initValues): bool {

        //loop over values and place them in the required/optional arrays
        foreach ( $initValues as $k => $v ) {
            if (array_key_exists( $k, self::$requiredInfo ) === true) {
                self::$requiredInfo[$k] = $v;
            }
            else {
                self::$optionalInfo[$k] = $v;
            }
        }

        //validate public key file path and prepare it
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

        //validate private key file path and prepare it
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

        //check for a false value in required fields
        if (in_array( false, array_values( self::$requiredInfo ) ) === false) {
            self::$pointers['serializer'] = new Silencenjoyer\Jwe\Serializers\CompactSerializer();
            return true;
        }
        else {
            self::$errors[] = 'Missing required fields';
            return false;
        }
    }



    /**
     * This method manages the oAuth access token retrieval as needed
     * @access private
     * @return mixed
     */
    private static function getAccessToken(): mixed {

        //further namespace cache name for oAuth access token
        $cacheID = self::$cachePrefix . 'api_accesstoken';

        //check if we have a cached token, if we do NOT (it has expired)
        if (cache::hasCache( $cacheID ) === false) {
            //build request parameters to get one
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

            //if successful, store access token in cache for lifetime-%arbitrarySeconds% so they are refreshed before true expiration
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
            //we already have a cached token, reuse it.
            return cache::getCache( $cacheID );
        }
    }



    /**
     * This method is a generic api call wrapper. It abstracts and utilizes another curl class
     * @access public
     * @param string $method the cURL Method (Post, Get, etc)
     * @param string $endpoint the URL to communicate with
     * @param array $bodyPayload array of HTTP POST keys=>vals for posts
     * @param array $additionalHeaders array http headers to include with the request
     * @return array
     */
    public static function doAPICall(string $method, string $endpoint, array $bodyPayload = array(), array $additionalHeaders = array()): array {

        //build promised return array    
        $return = array(
            'successState' => false,
            'errorMessage' => '',
            'data'         => null
        );

        //retrieve access token
        $accessToken = self::getAccessToken();

        if ($accessToken === false) {
            $return['errorMessage'] = 'Error retrieving access token';
            return $return;
        }

        //build request headers
        $headers = array(
            'Authorization: Bearer ' . $accessToken,
            'Accept: application/json',
            'alg: RSA-OAEP',
            'enc: A256GCM',
            'encryption: JWE',
            'client_id: ' . self::$requiredInfo['clientID'],
            'client_secret: ' . self::$requiredInfo['clientSecret']
        );

        //encode array payload to JWT string
        $jwt = Firebase\JWT\JWT::encode( $bodyPayload, self::$requiredInfo['clientSecret'], 'HS256' );
        $jwt = json_encode( $jwt );

        //encrypt JWT into a JWE string
        $compactJwe = self::$pointers['serializer']->serialize( self::$pointers['encryptor']->encrypt( $jwt ) );

        //make API call
        $apiResponse = curl::makeSingleRequest( $method, self::$requiredInfo['apiBaseURL'] . $endpoint, array( 'jwe' => $compactJwe ), $headers );

        if (intval( curl::$debugInfos['http_code'] ) === 200) {
            $return['successState'] = true;

            //decrypt returned JWE string
            $plaintext = self::$pointers['decryptor']->decrypt( self::$pointers['serializer']->unserialize( $apiResponse ) );

            //they do not sign the JWT with a valid signature so we cannot use JWT::decode, we do it manually.
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