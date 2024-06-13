<?php

/**
 * This is the pushover (notification app) class
 * @package MMExtranet
 */
class pushover_api {


    /**
     * private user key
     * @var string
     */
    private static $userKey = '';

    /**
     * private API key
     * @var string
     */
    private static $apiToken = '';

    /**
     * API url
     * @var string
     */
    private static $apiURL = 'https://api.pushover.net/1/messages.json';


    /**
     * This method initializes the class with the private keys
     * @access public
     * @param string $userKey the private user key
     * @param string $apiToken the private API key
     */
    public static function init(string $userKey, string $apiToken) {
        self::$userKey = $userKey;
        self::$apiToken = $apiToken;
    }

    public static function sendNotification(array $params) {
        $notificationParams = array();

        foreach ($params as $key => $val) {
            $notificationParams[$key] = $val;
        }

        //force user and api tokens
        $notificationParams['token'] = self::$apiToken;
        $notificationParams['user'] = self::$userKey;

        //ship it
        return curl::makeSingleRequest('POST', self::$apiURL, $notificationParams);
    }
}

/*
pushover_api::init('myUserKey', 'myApiToken');
pushover_api::sendNotification(array(
        'message' => 'Hello World!',
        'title' => 'My Title',
        'sound' => 'cashregister',
        'priority' => 1
    ));
*/
