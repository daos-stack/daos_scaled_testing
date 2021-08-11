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
 */
DELIMITER //
CREATE OR REPLACE FUNCTION compare_git_hash (
  hash1 TEXT,
  hash2 TEXT
) RETURNS BOOL
  BEGIN
    DECLARE len1 INTEGER;
    DECLARE len2 INTEGER;
    SET len1 := LENGTH(hash1);
    SET len2 := LENGTH(hash2);
    IF len1 > len2 THEN
        RETURN CONCAT(hash2, "%") LIKE hash1;
    ELSEIF len2 > len1 THEN
        RETURN CONCAT(hash1, "%") LIKE hash2;
    END IF;

    RETURN hash1 = hash2;
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
    IF val1 IS NULL OR val1 = 0 OR val2 IS NULL OR val2 = 0 THEN
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
