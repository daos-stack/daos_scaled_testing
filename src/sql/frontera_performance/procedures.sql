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
           ior1.chunk_size          AS "Chunk Size",
           ior1.xfer_size           AS "Xfer Size",
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
        AND compare_byte_repr(ior1.chunk_size, ior1.chunk_size)
        AND compare_byte_repr(ior1.xfer_size, ior2.xfer_size)
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


