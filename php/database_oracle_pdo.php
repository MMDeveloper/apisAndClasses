<?php

/**
 * This is the database interface class of the framework
 * @package MMExtranet
 */

class database_oracle_pdo {

    /**
     * SQL Server connection resource
     * @var object
     */
    private $link = null;

    /**
     * PDO prepared query reference
     * @var array
     */
    public $pdoReference = null;

    /**
     * array of queries run against this object
     * @var array
     */
    public $queries = array();

    /**
     * any errors resulting from queries
     * @var array
     */
    public $errors = array();

    /**
     * This method creates a connection to a database
     * @access public
     * @param string $dsn the connection DSN
     * @param string $username
     * @param string $password
     * @param bool $dieOnFailure to die or return bool on connection failure
     * @return mixed
     */
    public function connect(string $dsn, string $username, string $password, bool $dieOnFailure = true) {

        $return = true;

        $this->link = @oci_connect( $username, $password, $dsn );

        if ($this->link == false) {
            $return         = false;
            $this->errors[] = oci_error();
        }

        if ($return === true) {
            return true;
        }
        else {
            if ($dieOnFailure === true) {
                die( end( $this->errors ) );
            }
            else {
                return false;
            }
        }
    }



    /**
     * This method closes the PDO connection
     * @access public
     */
    public function closeConnection() {

        oci_close( $this->link );
        $this->link = null;
    }



    /**
     * This method executes a query and returns the raw result resource
     * @access public
     * @param string $sql string query
     * @param array $parameters for PDO query
     * @return object raw SQL result resource
     */
    public function justquery(string $sql, array $parameters = array()): bool {

        $this->queries[]    = $sql;
        $this->pdoReference = oci_parse( $this->link, $sql );

        if ($this->pdoReference === false) {
            $this->errors[] = oci_error( oci_parse( $this->link, $sql ) );
            return false;
        }
        else {
            foreach ( $parameters as $key => $val ) {
                oci_bind_by_name( $this->pdoReference, $key, $parameters[$key] );
            }

            $return = oci_execute( $this->pdoReference );

            if ($return === false) {
                $this->errors[] = oci_error( $this->pdoReference );
            }

            return $return;
        }
    }



    /**
     * This method loads the first value of the first column of the first row of results
     * @access public
     * @param string $sql string query
     * @param array $parameters for PDO query
     * @return mixed result from first column of first row of query results
     */
    public function loadResult(string $sql, array $parameters = array()) {

        if (!( $cur = $this->justquery( $sql, $parameters, false ) )) {
            $ret = false;
        }
        else {
            if ($row = $this->pdoReference->fetch( PDO::FETCH_NUM )) {
                $ret = $row[0];
            }
            else {
                $ret = false;
            }
        }

        return $ret;
    }



    /**
     * This method returns the first row of results
     * @access public
     * @param string $sql string query
     * @param array $parameters for PDO query
     * @return mixed object first row of results
     */
    public function loadFirstRow(string $sql, array $parameters = array()) {

        if (!( $cur = $this->justquery( $sql, $parameters ) )) {
            $ret = false;
        }
        else {
            if ($row = oci_fetch_object( $this->pdoReference )) {
                $ret = $row;
            }
            else {
                $ret = false;
            }
        }

        return $ret;
    }



    /**
     * This method returns the number of affected rows
     * @access public
     * @return int number affected rows
     */
    public function numAffectedRows(): int {

        return oci_num_rows( $this->pdoReference );
    }



    /**
     * This method queries the database, logs data, and returns results
     * @access public
     * @param string $sql single string query to run
     * @param array $parameters for PDO query
     * @param string $key if supplied, each group of results will be indexed with its respective $key's column value as its object index/position
     * @return unset|object depending on $returns, could be nothing, or an object of query results
     */
    public function query(string $sql, array $parameters = array(), string $key = '') {

        $result = array();
        $answer = $this->justquery( $sql, $parameters );

        if ($answer === false) {
            $this->errors[] = array( $sql, oci_error( $this->pdoReference ) );
            $result         = false;
        }
        else {
            while (( $row = oci_fetch_object( $this->pdoReference ) ) != false) {
                if ($key != '') {
                    $result[$row->$key] = $row;
                }
                else {
                    $result[] = $row;
                }
            }
        }

        return $result;
    }



    /**
     * This method generates a hash of the query and parameters, useful for caching
     * @access public
     * @param string $sql single string query to run
     * @param array $parameters for PDO query
     * @return string hash of query and parameters
     */
    public function queryID(string $sql, array $parameters = array()): string {

        $input = mb_eregi_replace( "\n", ' ', $sql );
        foreach ( $parameters as $k => $v ) {
            $input .= $k . $v;
        }
        return 'query.' . sha1( $input );
    }



}



/*
I feel the oracle driver implementation isn't too great as I could
not reliably catch errors on certain actions.
The $params argument is optional if there are no parameters in the query.
The $params argument is an associative array where the key is the parameter name
and the value is the parameter value.

$dsn = '(DESCRIPTION=
                    (ADDRESS=
                    (PROTOCOL=TCP)
                    (HOST=SCTDATA)
                    (PORT=1521)
                    )
                    (CONNECT_DATA=
                    (INSTANCE_NAME=PPRD)
                    (SERVER=dedicated)
                    (SERVICE_NAME=PPRD)
                    )
                )';

$database_oracle_pdo = new database_oracle_pdo();
$ret                 = $database_oracle_pdo->connect( $dsn, $username, $password, false );
if ($ret === false) {
    print_r($database_oracle_pdo->errors);
}
else {
    $sql = 'SELECT
                *
            FROM
                sometable
            WHERE
                payYear = :payYear
            AND
                payPeriod = :payPeriod';

    $params = array(
        ':payYear'   => 2025,
        ':payPeriod' => 2
    );

    //all rows
    $result = $database_oracle_pdo->query( $sql, $params );
    if ($result === false || count( $result ) == 0) {
        print_r($database_oracle_pdo->errors);
    }

    //just first row
    $result = $database_oracle_pdo->loadFirstRow( $sql, $params );
    if ($result === false) {
        print_r($database_oracle_pdo->errors);
    }

    //query with no return
    $sql = 'UPDATE
                sometable
            SET
                someValue = 1
            WHERE
                payYear = :payYear
            AND
                payPeriod = :payPeriod';
    $params = array(
        ':payYear'   => 2025,
        ':payPeriod' => 2
    );
    $result = $database_oracle_pdo->justquery( $sql, $params );
    if ($result === false) {
        print_r($database_oracle_pdo->errors);
    }
}
*/

?>