/**
 * Convert a string representation of a number of bytes to the numerical equivalent.
 * E.g. 1K -> 1024
 */
DELIMITER //
CREATE OR REPLACE FUNCTION byte_repr_to_int (
  byte_repr TEXT
) RETURNS INT
  BEGIN
    DECLARE len INT;
    SET len := LENGTH(byte_repr);
    SET byte_repr := UPPER(byte_repr);
    IF byte_repr like '%K' THEN
      RETURN LEFT(byte_repr, len - 1) * 1024;
    END IF;
    IF byte_repr like '%M' THEN
      RETURN LEFT(byte_repr, len - 1) * 1024 * 1024;
    END IF;
    IF byte_repr like '%G' THEN
      RETURN LEFT(byte_repr, len - 1) * 1024 * 1024 * 1024;
    END IF;
    RETURN CAST(byte_repr AS INT);
  END //
DELIMITER ;

/**
 * Compare two string representations of a bytes.
 * E.g. 1K = 1024, 1M != 1024
 */
DELIMITER //
CREATE OR REPLACE FUNCTION compare_byte_repr (
  val1 TEXT,
  val2 TEXT
) RETURNS BOOL
  BEGIN
    return byte_repr_to_int(val1) = byte_repr_to_int(val2);
  END //
DELIMITER ;

/**
 * Compare two git hashes that may be different lengths.
 * Supports wildcard %.
 */
DELIMITER //
CREATE OR REPLACE FUNCTION compare_git_hash (
  hash1 TEXT,
  hash2 TEXT
) RETURNS BOOL
  BEGIN
    RETURN hash1 LIKE CONCAT(hash2, "%") OR hash2 LIKE CONCAT(hash1, "%");
  END //
DELIMITER ;

/**
 * Calculate the percent difference between two values.
 */
DELIMITER //
CREATE OR REPLACE FUNCTION percent_diff (
  val1 float,
  val2 float
) RETURNS float
  BEGIN
    IF val1 IS NULL OR val1 = 0 THEN
        RETURN NULL;
    END IF;
    RETURN ROUND((val2 - val1) / val1 * 100, 2);
  END //
DELIMITER ;

/**
 * Calculate the percent difference between two values.
 * Formatted as text.
 */
DELIMITER //
CREATE OR REPLACE FUNCTION percent_diff_fm (
  val1 FLOAT,
  val2 FLOAT,
  fm_precision INTEGER
) RETURNS TEXT
  BEGIN
    RETURN CAST(ROUND(percent_diff(val1, val2), fm_precision) AS CHAR);
  END //
DELIMITER ;

/**
 * Compare two possibly NULL TEXT values. If either is NULL, treat them as equal.
 * TODO - better name for this.
 */
DELIMITER //
CREATE OR REPLACE FUNCTION compare_null_text(
  val1 TEXT,
  val2 TEXT
) RETURNS BOOL
  BEGIN
    RETURN (val1 IS NULL OR val2 IS NULL) OR (val1 = val2);
  END //
DELIMITER ;

/**
 * Compare two possibly NULL INT values. If either is NULL, treat them as equal.
 * TODO - better name for this.
 */
DELIMITER //
CREATE OR REPLACE FUNCTION compare_null_int(
  val1 INT,
  val2 INT
) RETURNS BOOL
  BEGIN
    RETURN (val1 IS NULL OR val2 IS NULL) OR (val1 = val2);
  END //
DELIMITER ;


/**
 * Get the number of data cells for an EC object class.
 */
DELIMITER //
CREATE OR REPLACE FUNCTION ec_data_cells(
  oclass TEXT
) RETURNS INT
  BEGIN
    DECLARE m TEXT;
    DECLARE data_cells TEXT;
    SET m := REGEXP_SUBSTR(oclass, '_[0-9]*P');
    SET data_cells = SUBSTR(m, 2, LENGTH(m) - 2);
    IF data_cells IS NULL or data_cells = '' THEN
        RETURN NULL;
    END IF;
    RETURN CAST(data_cells AS INT);
  END //
DELIMITER ;

/**
 * Get the number of parity cells for an EC object class.
 */
DELIMITER //
CREATE OR REPLACE FUNCTION ec_parity_cells(
  oclass TEXT
) RETURNS INT
  BEGIN
    DECLARE m TEXT;
    DECLARE parity_cells TEXT;
    SET m := REGEXP_SUBSTR(oclass, 'P[0-9]*G');
    SET parity_cells = SUBSTR(m, 2, LENGTH(m) - 2);
    IF parity_cells IS NULL or PARITY_CELLS = '' THEN
        RETURN NULL;
    END IF;
    RETURN CAST(parity_cells AS INT);
  END //
DELIMITER ;

/**
 * Get the number of groups for an EC object class.
 */
DELIMITER //
CREATE OR REPLACE FUNCTION ec_groups(
  oclass TEXT
) RETURNS TEXT
  BEGIN
    DECLARE m TEXT;
    DECLARE groups TEXT;
    SET m := REGEXP_SUBSTR(oclass, 'G[0-9X]*$');
    SET groups = SUBSTR(m, 2, LENGTH(m) - 1);
    RETURN groups;
  END //
DELIMITER ;

/**
 * For a given EC object class and number of servers and targets,
 * get the equivalent rf0 S object class that will use the same number of targets.
 */
DELIMITER //
CREATE OR REPLACE FUNCTION equivalent_oclass_S(
  ec_oclass TEXT,
  num_servers INT,
  num_targets INT
) RETURNS TEXT
  BEGIN
    DECLARE data_cells INT;
    DECLARE parity_cells INT;
    DECLARE groups TEXT;
    DECLARE shards INT;
    SET data_cells := ec_data_cells(ec_oclass);
    IF data_cells IS NULL THEN
        RETURN NULL;
    END IF;
    SET parity_cells := ec_parity_cells(ec_oclass);
    IF parity_cells IS NULL THEN
        RETURN NULL;
    END IF;
    SET groups := ec_groups(ec_oclass);
    IF groups IS NULL THEN
        RETURN NULL;
    END IF;
    IF groups = 'X' THEN
        SET groups := (num_servers * num_targets) / (data_cells + parity_cells);
    END IF;
    SET shards := data_cells * groups;
    RETURN CONCAT('S', shards);
  END //
DELIMITER ;

/**
 * Get sort order for an object class.
 */
DELIMITER //
CREATE OR REPLACE FUNCTION oclass_sort(
  oclass TEXT
) RETURNS TEXT
  BEGIN
    DECLARE m TEXT;
    DECLARE s TEXT;
    DECLARE sort TEXT;

    SET oclass := UPPER(oclass);

    SET m := REGEXP_SUBSTR(oclass, '^S[0-9X]*$');
    IF m != '' THEN
      SET sort := '1';
      SET s := SUBSTR(m, 2, LENGTH(m) - 1);
      IF s = 'X' THEN
        SET s := '0';
      END IF;
      RETURN CONCAT(sort, LPAD(s, 4, '0'));
    END IF;

    SET m := REGEXP_SUBSTR(oclass, '^RP_[0-9]*G');
    IF m != '' THEN
      SET sort := '2';
      SET sort := CONCAT(sort, LPAD(SUBSTR(m, 4, LENGTH(m) - 4), 4, '0'));
      SET m := REGEXP_SUBSTR(oclass, 'G[0-9X]*$');
      SET s := SUBSTR(m, 2, LENGTH(m) - 1);
      IF s = 'X' THEN
        SET s := '0';
      END IF;
      RETURN CONCAT(sort, LPAD(s, 4, '0'));
    END IF;

    SET m := REGEXP_SUBSTR(oclass, '^EC_[0-9]*P');
    IF m != '' THEN
      SET sort := '3';
      SET sort := CONCAT(sort, LPAD(SUBSTR(m, 4, LENGTH(m) - 4), 4, '0'));
      SET m := REGEXP_SUBSTR(oclass, 'P[0-9]*G');
      SET sort := CONCAT(sort, LPAD(SUBSTR(m, 2, LENGTH(m) - 2), 4, '0'));
      SET m := REGEXP_SUBSTR(oclass, 'G[0-9X]*$');
      SET s := SUBSTR(m, 2, LENGTH(m) - 1);
      IF s = 'X' THEN
        SET s := '0';
      END IF;
      RETURN CONCAT(sort, LPAD(s, 4, '0'));
    END IF;

    RETURN NULL;
  END //
DELIMITER ;


/**
 * Get sort order for server/client combination.
 * Orders 1:4 first, followed by c16.
 */
DELIMITER //
CREATE OR REPLACE FUNCTION server_client_sort(
  num_servers INT,
  num_clients INT
) RETURNS INT
  BEGIN
    IF num_clients = num_servers * 4 THEN
      RETURN 100000000 + (num_servers * 10000000) + (num_clients * 1000);
    END IF;
      RETURN 200000000 + (num_servers * 10000000) + (num_clients * 1000);
  END //
DELIMITER ;
