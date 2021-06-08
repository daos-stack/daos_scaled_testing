DROP DATABASE IF EXISTS frontera_performance;
CREATE DATABASE frontera_performance COMMENT 'frontera performance metrics';
USE frontera_performance;


/*
    TABLES
*/

CREATE OR REPLACE TABLE results_ior (
    id           bigint PRIMARY KEY DEFAULT uuid_short(),
    slurm_job_id bigint UNIQUE,
    test_case    varchar(40) NOT NULL,
    start_time   datetime NOT NULL,
    end_time     datetime,
    test_eta_min int GENERATED ALWAYS AS (TIMESTAMPDIFF(MINUTE, start_time, end_time))
                 COMMENT "difference in minutes between start_time and end_time",
    daos_commit  varchar(40) NOT NULL,
    oclass       varchar(40) NOT NULL,
    num_servers  int NOT NULL,
    num_clients  int NOT NULL,
    ppc          int NOT NULL
                 COMMENT "processes per client",
    num_ranks    int GENERATED ALWAYS AS(num_clients * ppc),
    fpp          bool
                 COMMENT "file per process",
    segments     int,
    xfer_size    varchar(40),
    block_size   varchar(40),
    cont_rf      int,
    ec_cell_size int,
    iterations   int,
    sw_time      int,
    notes        varchar(400),
    status       varchar(40) NOT NULL
                 COMMENT "pass/fail/etc.",
    write_gib    float,
    read_gib     float
) COMMENT "ior performance results";


CREATE OR REPLACE TABLE results_mdtest (
    id           bigint PRIMARY KEY DEFAULT uuid_short(),
    slurm_job_id bigint UNIQUE,
    test_case    varchar(40) NOT NULL,
    start_time   datetime NOT NULL,
    end_time     datetime,
    test_eta_min int GENERATED ALWAYS AS (TIMESTAMPDIFF(MINUTE, start_time, end_time)),
    daos_commit  varchar(40) NOT NULL,
    oclass       varchar(40) NOT NULL,
    dir_oclass   varchar(40) NOT NULL,
    num_servers  int NOT NULL,
    num_clients  int NOT NULL,
    ppc          int NOT NULL,
    num_ranks    int GENERATED ALWAYS AS(num_clients * ppc),
    notes        varchar(400),
    status       varchar(40) NOT NULL,
    sw_time      int,
    n_file       int,
    chunk_size   varchar(40),
    bytes_read   int,
    bytes_write  int,
    tree_depth   varchar(40),
    create_kops  float,
    stat_kops    float,
    read_kops    float,
    remove_kops  float
) COMMENT "mdtest performance results";


CREATE OR REPLACE TABLE results_rebuild (
    id                        bigint PRIMARY KEY DEFAULT uuid_short(),
    slurm_job_id              bigint UNIQUE,
    test_case                 varchar(40) NOT NULL,
    start_time                datetime NOT NULL,
    end_time                  datetime,
    test_eta_min              int GENERATED ALWAYS AS (TIMESTAMPDIFF(MINUTE, start_time, end_time)),
    daos_commit               varchar(40) NOT NULL,
    num_servers               int NOT NULL,
    num_clients               int NOT NULL,
    ppc                       int NOT NULL,
    num_ranks                 int GENERATED ALWAYS AS (num_clients * ppc),
    num_pools                 int NOT NULL,
    num_targets               int NOT NULL,
    pool_size                 varchar(40) NOT NULL,
    notes                     varchar(400),
    status                    varchar(40) NOT NULL,
    rebuild_kill_time         datetime
                              COMMENT "when the server was killed",
    rebuild_down_time         datetime
                              COMMENT "first down message",
    rebuild_queued_time       datetime
                              COMMENT "first rebuild queued message",
    rebuild_completed_time    datetime
                              COMMENT "last rebuild completed message",
    rebuild_kill_to_down      int GENERATED ALWAYS AS (TIMESTAMPDIFF(SECOND, rebuild_kill_time, rebuild_down_time))
                              COMMENT "time from kill to dead",
    rebuild_kill_to_queued    int GENERATED ALWAYS AS (TIMESTAMPDIFF(SECOND, rebuild_kill_time, rebuild_queued_time))
                              COMMENT "time from kill to queued",
    rebuild_kill_to_completed int GENERATED ALWAYS AS (TIMESTAMPDIFF(SECOND, rebuild_kill_time, rebuild_completed_time))
                              COMMENT "time from kill to completed"
) COMMENT "rebuild performance results";


/*
    FUNCTIONS
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

DELIMITER //
CREATE OR REPLACE FUNCTION compare_null_text(
  val1 TEXT,
  val2 TEXT
) RETURNS BOOL
  BEGIN
    RETURN (val1 IS NULL OR val2 IS NULL) OR (val1 = val2);
  END //
DELIMITER ;

DELIMITER //
CREATE OR REPLACE FUNCTION compare_null_int(
  val1 INT,
  val2 INT
) RETURNS BOOL
  BEGIN
    RETURN (val1 IS NULL OR val2 IS NULL) OR (val1 = val2);
  END //
DELIMITER ;


/*
    PROCEDURES
*/


DELIMITER //
CREATE OR REPLACE PROCEDURE compare_ior (
  IN test_case_in TEXT,
  IN oclass1_in TEXT,
  IN oclass2_in TEXT,
  IN daos_commit1_in TEXT,
  IN daos_commit2_in TEXT
)
 BEGIN
    SELECT ior1.slurm_job_id        AS "slurm_job_id1",
           ior2.slurm_job_id        AS "slurm_job_id2",
           ior1.daos_commit         AS "DAOS Commit1",
           ior2.daos_commit         AS "DAOS Commit2",
           ior1.oclass              AS "oclass1",
           ior2.oclass              AS "oclass2",
           ior1.num_servers         AS "#Servers",
           ior1.num_clients         AS "#Clients",
           round(ior1.write_gib, 2) AS "write_gib1",
           round(ior2.write_gib, 2) AS "write_gib2",
           round(ior1.read_gib, 2)  AS "read_gib1",
           round(ior2.read_gib, 2)  AS "read_gib2",
           CAST(round(percent_diff(ior1.write_gib, ior2.write_gib), 2) AS CHAR) AS "write_gib%",
           CAST(round(percent_diff(ior1.read_gib, ior2.read_gib), 2) AS CHAR)   AS "read_gib%"
    FROM results_ior ior1 JOIN results_ior ior2
      USING (num_servers, num_clients)
      WHERE ior1.id != ior2.id
        AND compare_null_int(ior1.fpp, ior2.fpp)                -- not necessary if test_case is comprehensive
        AND compare_null_int(ior1.segments, ior2.segments)      -- not necessary if test_case is comprehensive
        AND compare_null_text(ior1.xfer_size, ior2.xfer_size)   -- not necessary if test_case is comprehensive
        AND compare_null_text(ior1.block_size, ior2.block_size) -- not necessary if test_case is comprehensive
        AND compare_null_int(ior1.cont_rf, ior2.cont_rf)        -- not necessary if test_case is comprehensive
        AND compare_null_int(ior1.iterations, ior2.iterations)  -- not necessary if test_case is comprehensive
        AND ior1.oclass LIKE oclass1_in
        AND ior2.oclass LIKE oclass2_in
        AND ior1.test_case LIKE test_case_in
        AND ior2.test_case LIKE test_case_in
        AND ((daos_commit1_in IS NULL)
          OR (ior1.daos_commit LIKE CONCAT(SUBSTRING(daos_commit1_in, 1, LENGTH(ior1.daos_commit)), "%")))
        AND ((daos_commit2_in IS NULL)
          OR (ior2.daos_commit LIKE CONCAT(SUBSTRING(daos_commit2_in, 1, LENGTH(ior2.daos_commit)), "%")))
      ORDER BY ior1.daos_commit, ior2.daos_commit, ior1.oclass, ior2.oclass, ior1.num_servers, ior1.num_clients;
  END //
DELIMITER ;


DELIMITER //
CREATE OR REPLACE PROCEDURE compare_ior_1to4 (
  IN test_case_in TEXT,
  IN oclass1_in TEXT,
  IN oclass2_in TEXT,
  IN daos_commit1_in TEXT,
  IN daos_commit2_in TEXT
)
 BEGIN
    SELECT ior1.slurm_job_id        AS "slurm_job_id1",
           ior2.slurm_job_id        AS "slurm_job_id2",
           ior1.daos_commit         AS "DAOS Commit1",
           ior2.daos_commit         AS "DAOS Commit2",
           ior1.oclass              AS "oclass1",
           ior2.oclass              AS "oclass2",
           ior1.num_servers         AS "#Servers",
           ior1.num_clients         AS "#Clients",
           round(ior1.write_gib, 2) AS "write_gib1",
           round(ior2.write_gib, 2) AS "write_gib2",
           round(ior1.read_gib, 2)  AS "read_gib1",
           round(ior2.read_gib, 2)  AS "read_gib2",
           CAST(round(percent_diff(ior1.write_gib, ior2.write_gib), 2) AS CHAR) AS "write_gib%",
           CAST(round(percent_diff(ior1.read_gib, ior2.read_gib), 2) AS CHAR)   AS "read_gib%"
    FROM results_ior ior1 JOIN results_ior ior2
      USING (num_servers, num_clients)
      WHERE ior1.id != ior2.id
        AND ior1.num_clients = (ior1.num_servers * 4)
        AND compare_null_int(ior1.fpp, ior2.fpp)                -- not necessary if test_case is comprehensive
        AND compare_null_int(ior1.segments, ior2.segments)      -- not necessary if test_case is comprehensive
        AND compare_null_text(ior1.xfer_size, ior2.xfer_size)   -- not necessary if test_case is comprehensive
        AND compare_null_text(ior1.block_size, ior2.block_size) -- not necessary if test_case is comprehensive
        AND compare_null_int(ior1.cont_rf, ior2.cont_rf)        -- not necessary if test_case is comprehensive
        AND compare_null_int(ior1.iterations, ior2.iterations)  -- not necessary if test_case is comprehensive
        AND ior1.oclass LIKE oclass1_in
        AND ior2.oclass LIKE oclass2_in
        AND ior1.test_case LIKE test_case_in
        AND ior2.test_case LIKE test_case_in
        AND ((daos_commit1_in IS NULL)
          OR (ior1.daos_commit LIKE CONCAT(SUBSTRING(daos_commit1_in, 1, LENGTH(ior1.daos_commit)), "%")))
        AND ((daos_commit2_in IS NULL)
          OR (ior2.daos_commit LIKE CONCAT(SUBSTRING(daos_commit2_in, 1, LENGTH(ior2.daos_commit)), "%")))
      ORDER BY ior1.daos_commit, ior2.daos_commit, ior1.oclass, ior2.oclass, ior1.num_servers, ior1.num_clients;
  END //
DELIMITER ;


DELIMITER //
CREATE OR REPLACE PROCEDURE compare_ior_c16 (
  IN test_case_in TEXT,
  IN oclass1_in TEXT,
  IN oclass2_in TEXT,
  IN daos_commit1_in TEXT,
  IN daos_commit2_in TEXT
)
 BEGIN
    SELECT ior1.slurm_job_id        AS "slurm_job_id1",
           ior2.slurm_job_id        AS "slurm_job_id2",
           ior1.daos_commit         AS "DAOS Commit1",
           ior2.daos_commit         AS "DAOS Commit2",
           ior1.oclass              AS "oclass1",
           ior2.oclass              AS "oclass2",
           ior1.num_servers         AS "#Servers",
           ior1.num_clients         AS "#Clients",
           round(ior1.write_gib, 2) AS "write_gib1",
           round(ior2.write_gib, 2) AS "write_gib2",
           round(ior1.read_gib, 2)  AS "read_gib1",
           round(ior2.read_gib, 2)  AS "read_gib2",
           CAST(round(percent_diff(ior1.write_gib, ior2.write_gib), 2) AS CHAR) AS "write_gib%",
           CAST(round(percent_diff(ior1.read_gib, ior2.read_gib), 2) AS CHAR)   AS "read_gib%"
    FROM results_ior ior1 JOIN results_ior ior2
      USING (num_servers, num_clients)
      WHERE ior1.id != ior2.id
        AND ior1.num_clients = 16
        AND compare_null_int(ior1.fpp, ior2.fpp)                -- not necessary if test_case is comprehensive
        AND compare_null_int(ior1.segments, ior2.segments)      -- not necessary if test_case is comprehensive
        AND compare_null_text(ior1.xfer_size, ior2.xfer_size)   -- not necessary if test_case is comprehensive
        AND compare_null_text(ior1.block_size, ior2.block_size) -- not necessary if test_case is comprehensive
        AND compare_null_int(ior1.cont_rf, ior2.cont_rf)        -- not necessary if test_case is comprehensive
        AND compare_null_int(ior1.iterations, ior2.iterations)  -- not necessary if test_case is comprehensive
        AND ior1.oclass LIKE oclass1_in
        AND ior2.oclass LIKE oclass2_in
        AND ior1.test_case LIKE test_case_in
        AND ior2.test_case LIKE test_case_in
        AND ((daos_commit1_in IS NULL)
          OR (ior1.daos_commit LIKE CONCAT(SUBSTRING(daos_commit1_in, 1, LENGTH(ior1.daos_commit)), "%")))
        AND ((daos_commit2_in IS NULL)
          OR (ior2.daos_commit LIKE CONCAT(SUBSTRING(daos_commit2_in, 1, LENGTH(ior2.daos_commit)), "%")))
      ORDER BY ior1.daos_commit, ior2.daos_commit, ior1.oclass, ior2.oclass, ior1.num_servers, ior1.num_clients;
  END //
DELIMITER ;


DELIMITER //
CREATE OR REPLACE PROCEDURE compare_mdtest (
  IN test_case_in TEXT,
  IN oclass1_in TEXT,
  IN oclass2_in TEXT,
  IN daos_commit1_in TEXT,
  IN daos_commit2_in TEXT
)
 BEGIN
    SELECT mdtest1.slurm_job_id          AS "slurm_job_id1",
           mdtest2.slurm_job_id          AS "slurm_job_id2",
           mdtest1.daos_commit           AS "DAOS Commit1",
           mdtest2.daos_commit           AS "DAOS Commit2",
           mdtest1.oclass                AS "oclass1",
           mdtest2.oclass                AS "oclass2",
           mdtest1.num_servers           AS "#Servers",
           mdtest1.num_clients           AS "#Clients",
           round(mdtest1.create_kops, 2) AS "create_kops1",
           round(mdtest2.create_kops, 2) AS "create_kops2",
           round(mdtest1.stat_kops, 2)   AS "stat_kops1",
           round(mdtest2.stat_kops, 2)   AS "stat_kops2",
           round(mdtest1.read_kops, 2)   AS "read_kops1",
           round(mdtest2.read_kops, 2)   AS "read_kops2",
           round(mdtest1.remove_kops, 2) AS "remove_kops1",
           round(mdtest2.remove_kops, 2) AS "remove_kops2",
           CAST(round(percent_diff(mdtest1.create_kops, mdtest2.create_kops), 2)AS CHAR) AS "create%",
           CAST(round(percent_diff(mdtest1.stat_kops, mdtest2.stat_kops), 2) AS CHAR) AS "stat%",
           CAST(round(percent_diff(mdtest1.read_kops, mdtest2.read_kops), 2) AS CHAR) AS "read%",
           CAST(round(percent_diff(mdtest1.remove_kops, mdtest2.remove_kops), 2) AS CHAR) AS "remove%"
    FROM results_mdtest mdtest1 JOIN results_mdtest mdtest2
      USING (num_servers, num_clients)
      WHERE mdtest1.id != mdtest2.id
        AND mdtest1.oclass LIKE oclass1_in
        AND mdtest2.oclass LIKE oclass2_in
        AND mdtest1.test_case LIKE test_case_in
        AND mdtest2.test_case LIKE test_case_in
        AND ((daos_commit1_in IS NULL)
          OR (mdtest1.daos_commit LIKE CONCAT(SUBSTRING(daos_commit1_in, 1, LENGTH(mdtest1.daos_commit)), "%")))
        AND ((daos_commit2_in IS NULL)
          OR (mdtest2.daos_commit LIKE CONCAT(SUBSTRING(daos_commit2_in, 1, LENGTH(mdtest2.daos_commit)), "%")))
      ORDER BY mdtest1.daos_commit, mdtest2.daos_commit, mdtest1.oclass, mdtest2.oclass, mdtest1.num_servers, mdtest1.num_clients;
  END //
DELIMITER ;


DELIMITER //
CREATE OR REPLACE PROCEDURE compare_mdtest_1to4 (
  IN test_case_in TEXT,
  IN oclass1_in TEXT,
  IN oclass2_in TEXT,
  IN daos_commit1_in TEXT,
  IN daos_commit2_in TEXT
)
 BEGIN
    SELECT mdtest1.slurm_job_id          AS "slurm_job_id1",
           mdtest2.slurm_job_id          AS "slurm_job_id2",
           mdtest1.daos_commit           AS "DAOS Commit1",
           mdtest2.daos_commit           AS "DAOS Commit2",
           mdtest1.oclass                AS "oclass1",
           mdtest2.oclass                AS "oclass2",
           mdtest1.num_servers           AS "#Servers",
           mdtest1.num_clients           AS "#Clients",
           round(mdtest1.create_kops, 2) AS "create_kops1",
           round(mdtest2.create_kops, 2) AS "create_kops2",
           round(mdtest1.stat_kops, 2)   AS "stat_kops1",
           round(mdtest2.stat_kops, 2)   AS "stat_kops2",
           round(mdtest1.read_kops, 2)   AS "read_kops1",
           round(mdtest2.read_kops, 2)   AS "read_kops2",
           round(mdtest1.remove_kops, 2) AS "remove_kops1",
           round(mdtest2.remove_kops, 2) AS "remove_kops2",
           CAST(round(percent_diff(mdtest1.create_kops, mdtest2.create_kops), 2)AS CHAR) AS "create%",
           CAST(round(percent_diff(mdtest1.stat_kops, mdtest2.stat_kops), 2) AS CHAR) AS "stat%",
           CAST(round(percent_diff(mdtest1.read_kops, mdtest2.read_kops), 2) AS CHAR) AS "read%",
           CAST(round(percent_diff(mdtest1.remove_kops, mdtest2.remove_kops), 2) AS CHAR) AS "remove%"
    FROM results_mdtest mdtest1 JOIN results_mdtest mdtest2
      USING (num_servers, num_clients)
      WHERE mdtest1.id != mdtest2.id
        AND mdtest1.num_clients = (mdtest1.num_servers * 4)
        AND mdtest1.oclass LIKE oclass1_in
        AND mdtest2.oclass LIKE oclass2_in
        AND mdtest1.test_case LIKE test_case_in
        AND mdtest2.test_case LIKE test_case_in
        AND ((daos_commit1_in IS NULL)
          OR (mdtest1.daos_commit LIKE CONCAT(SUBSTRING(daos_commit1_in, 1, LENGTH(mdtest1.daos_commit)), "%")))
        AND ((daos_commit2_in IS NULL)
          OR (mdtest2.daos_commit LIKE CONCAT(SUBSTRING(daos_commit2_in, 1, LENGTH(mdtest2.daos_commit)), "%")))
      ORDER BY mdtest1.daos_commit, mdtest2.daos_commit, mdtest1.oclass, mdtest2.oclass, mdtest1.num_servers, mdtest1.num_clients;
  END //
DELIMITER ;


DELIMITER //
CREATE OR REPLACE PROCEDURE compare_mdtest_c16 (
  IN test_case_in TEXT,
  IN oclass1_in TEXT,
  IN oclass2_in TEXT,
  IN daos_commit1_in TEXT,
  IN daos_commit2_in TEXT
)
 BEGIN
    SELECT mdtest1.slurm_job_id          AS "slurm_job_id1",
           mdtest2.slurm_job_id          AS "slurm_job_id2",
           mdtest1.daos_commit           AS "DAOS Commit1",
           mdtest2.daos_commit           AS "DAOS Commit2",
           mdtest1.oclass                AS "oclass1",
           mdtest2.oclass                AS "oclass2",
           mdtest1.num_servers           AS "#Servers",
           mdtest1.num_clients           AS "#Clients",
           round(mdtest1.create_kops, 2) AS "create_kops1",
           round(mdtest2.create_kops, 2) AS "create_kops2",
           round(mdtest1.stat_kops, 2)   AS "stat_kops1",
           round(mdtest2.stat_kops, 2)   AS "stat_kops2",
           round(mdtest1.read_kops, 2)   AS "read_kops1",
           round(mdtest2.read_kops, 2)   AS "read_kops2",
           round(mdtest1.remove_kops, 2) AS "remove_kops1",
           round(mdtest2.remove_kops, 2) AS "remove_kops2",
           CAST(round(percent_diff(mdtest1.create_kops, mdtest2.create_kops), 2)AS CHAR) AS "create%",
           CAST(round(percent_diff(mdtest1.stat_kops, mdtest2.stat_kops), 2) AS CHAR) AS "stat%",
           CAST(round(percent_diff(mdtest1.read_kops, mdtest2.read_kops), 2) AS CHAR) AS "read%",
           CAST(round(percent_diff(mdtest1.remove_kops, mdtest2.remove_kops), 2) AS CHAR) AS "remove%"
    FROM results_mdtest mdtest1 JOIN results_mdtest mdtest2
      USING (num_servers, num_clients)
      WHERE mdtest1.id != mdtest2.id
        AND mdtest1.num_clients = 16
        AND mdtest1.oclass LIKE oclass1_in
        AND mdtest2.oclass LIKE oclass2_in
        AND mdtest1.test_case LIKE test_case_in
        AND mdtest2.test_case LIKE test_case_in
        AND ((daos_commit1_in IS NULL)
          OR (mdtest1.daos_commit LIKE CONCAT(SUBSTRING(daos_commit1_in, 1, LENGTH(mdtest1.daos_commit)), "%")))
        AND ((daos_commit2_in IS NULL)
          OR (mdtest2.daos_commit LIKE CONCAT(SUBSTRING(daos_commit2_in, 1, LENGTH(mdtest2.daos_commit)), "%")))
      ORDER BY mdtest1.daos_commit, mdtest2.daos_commit, mdtest1.oclass, mdtest2.oclass, mdtest1.num_servers, mdtest1.num_clients;
  END //
DELIMITER ;


DELIMITER //
CREATE OR REPLACE PROCEDURE compare_mdtest_1server (
  IN test_case_in TEXT,
  IN oclass1_in TEXT,
  IN oclass2_in TEXT,
  IN daos_commit1_in TEXT,
  IN daos_commit2_in TEXT
)
 BEGIN
    SELECT mdtest1.slurm_job_id          AS "slurm_job_id1",
           mdtest2.slurm_job_id          AS "slurm_job_id2",
           mdtest1.daos_commit           AS "DAOS Commit1",
           mdtest2.daos_commit           AS "DAOS Commit2",
           mdtest1.oclass                AS "oclass1",
           mdtest2.oclass                AS "oclass2",
           mdtest1.num_servers           AS "#Servers",
           mdtest1.num_clients           AS "#Clients",
           round(mdtest1.create_kops, 2) AS "create_kops1",
           round(mdtest2.create_kops, 2) AS "create_kops2",
           round(mdtest1.stat_kops, 2)   AS "stat_kops1",
           round(mdtest2.stat_kops, 2)   AS "stat_kops2",
           round(mdtest1.read_kops, 2)   AS "read_kops1",
           round(mdtest2.read_kops, 2)   AS "read_kops2",
           round(mdtest1.remove_kops, 2) AS "remove_kops1",
           round(mdtest2.remove_kops, 2) AS "remove_kops2",
           CAST(round(percent_diff(mdtest1.create_kops, mdtest2.create_kops), 2)AS CHAR) AS "create%",
           CAST(round(percent_diff(mdtest1.stat_kops, mdtest2.stat_kops), 2) AS CHAR) AS "stat%",
           CAST(round(percent_diff(mdtest1.read_kops, mdtest2.read_kops), 2) AS CHAR) AS "read%",
           CAST(round(percent_diff(mdtest1.remove_kops, mdtest2.remove_kops), 2) AS CHAR) AS "remove%"
    FROM results_mdtest mdtest1 JOIN results_mdtest mdtest2
      USING (num_servers, num_clients)
      WHERE mdtest1.id != mdtest2.id
        AND mdtest1.num_servers = 1
        AND mdtest1.num_clients = 4
        AND mdtest1.oclass LIKE oclass1_in
        AND mdtest2.oclass LIKE oclass2_in
        AND mdtest1.test_case LIKE test_case_in
        AND mdtest2.test_case LIKE test_case_in
        AND ((daos_commit1_in IS NULL)
          OR (mdtest1.daos_commit LIKE CONCAT(SUBSTRING(daos_commit1_in, 1, LENGTH(mdtest1.daos_commit)), "%")))
        AND ((daos_commit2_in IS NULL)
          OR (mdtest2.daos_commit LIKE CONCAT(SUBSTRING(daos_commit2_in, 1, LENGTH(mdtest2.daos_commit)), "%")))
      ORDER BY mdtest1.daos_commit, mdtest2.daos_commit, mdtest1.oclass, mdtest2.oclass, mdtest1.num_servers, mdtest1.num_clients;
  END //
DELIMITER ;


DELIMITER //
CREATE OR REPLACE PROCEDURE show_rebuild (
  IN daos_commit_in TEXT
)
 BEGIN
    SELECT rebuild.slurm_job_id,
           rebuild.daos_commit                            AS "DAOS Commit",
           rebuild.num_servers                            AS "#Servers",
           rebuild.num_pools                              AS "#Pools",
           rebuild.pool_size                              AS "Pool Size",
           rebuild.num_targets                            AS "#Targets",
           CAST(rebuild.rebuild_kill_time AS TIME)        AS "Killed At",
           CAST(rebuild.rebuild_down_time AS TIME)        AS "Down At",
           CAST(rebuild.rebuild_queued_time AS TIME)      AS "Queued At",
           CAST(rebuild.rebuild_completed_time AS TIME)   AS "Completed At",
           SEC_TO_TIME(rebuild.rebuild_kill_to_down)      AS "Kill->Down",
           SEC_TO_TIME(rebuild.rebuild_kill_to_queued)    AS "Kill->Queued",
           SEC_TO_TIME(rebuild.rebuild_kill_to_completed) AS "Kill->Completed",
           rebuild.status                    AS "Status"
    FROM results_rebuild rebuild
      WHERE ((daos_commit_in IS NULL)
          OR ((rebuild.daos_commit LIKE CONCAT(SUBSTRING(daos_commit_in, 1, LENGTH(rebuild.daos_commit)), "%"))))
      ORDER BY rebuild.daos_commit, rebuild.num_servers, rebuild.num_pools, rebuild.pool_size, rebuild.num_targets;
  END //
DELIMITER ;


