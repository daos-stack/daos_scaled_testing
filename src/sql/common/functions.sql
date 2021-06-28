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
