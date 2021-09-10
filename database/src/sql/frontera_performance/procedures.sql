DELIMITER //
CREATE OR REPLACE PROCEDURE compare_ior (
  IN test_case_in TEXT,
  IN oclass1_in TEXT,
  IN oclass2_in TEXT,
  IN daos_commit1_in TEXT,
  IN daos_commit2_in TEXT,
  IN subtype_in TEXT
)
 BEGIN
    IF oclass1_in IS NULL THEN SET oclass1_in := '%'; END IF;
    IF oclass2_in IS NULL THEN SET oclass2_in := '%'; END IF;
    IF daos_commit1_in IS NULL THEN SET daos_commit1_in := '%'; END IF;
    IF daos_commit2_in IS NULL THEN SET daos_commit2_in := '%'; END IF;

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
        AND ((subtype_in IS NULL)
          OR (subtype_in = '1to4' AND ior1.num_clients = (ior1.num_servers * 4))
          OR (subtype_in = 'c16' AND ior1.num_clients = 16))
        AND ior1.oclass LIKE oclass1_in
        AND ior2.oclass LIKE oclass2_in
        AND ior1.test_case LIKE test_case_in
        AND ior2.test_case LIKE test_case_in
        AND compare_git_hash(ior1.daos_commit, daos_commit1_in)
        AND compare_git_hash(ior2.daos_commit, daos_commit2_in)
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
    CALL compare_ior(test_case_in, oclass1_in, oclass2_in, daos_commit1_in, daos_commit2_in, '1to4');
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
    CALL compare_ior(test_case_in, oclass1_in, oclass2_in, daos_commit1_in, daos_commit2_in, 'c16');
  END //
DELIMITER ;


DELIMITER //
CREATE OR REPLACE PROCEDURE compare_ior_s_ec (
  IN test_case_in TEXT,
  IN ec_oclass_in TEXT,
  IN s_commit_in TEXT,
  IN ec_commit_in TEXT
)
 BEGIN
    IF ec_oclass_in IS NULL THEN SET ec_oclass_in := '%'; END IF;
    IF s_commit_in IS NULL THEN SET s_commit_in := '%'; END IF;
    IF ec_commit_in IS NULL THEN SET ec_commit_in := '%'; END IF;

    SELECT s_ior.slurm_job_id         AS "S slurm_job_id",
           ec_ior.slurm_job_id        AS "EC slurm_job_id",
           s_ior.daos_commit          AS "S Commit",
           ec_ior.daos_commit         AS "EC Commit",
           s_ior.oclass               AS "S Oclass",
           ec_ior.oclass              AS "EC Oclass",
           s_ior.num_servers          AS "#Servers",
           s_ior.num_clients          AS "#Clients",
           s_ior.chunk_size           AS "S Chunk",
           s_ior.xfer_size            AS "S Xfer",
           ec_ior.chunk_size          AS "EC Chunk",
           ec_ior.xfer_size           AS "EC xfer",
           round(s_ior.write_gib, 2)  AS "S write_gib",
           round(ec_ior.write_gib, 2) AS "EC write_gib",
           round(s_ior.read_gib, 2)   AS "S read_gib",
           round(ec_ior.read_gib, 2)  AS "EC read_gib",
           CAST(round(percent_diff(s_ior.write_gib, ec_ior.write_gib), 2) AS CHAR) AS "write_gib%",
           CAST(round(percent_diff(s_ior.read_gib, ec_ior.read_gib), 2) AS CHAR)   AS "read_gib%"
    FROM results_ior ec_ior JOIN results_ior s_ior
      USING (num_servers, num_clients, num_targets)
      WHERE s_ior.id != ec_ior.id
        AND ec_ior.oclass LIKE ec_oclass_in
        AND s_ior.oclass = equivalent_oclass_S(ec_ior.oclass, ec_ior.num_servers, ec_ior.num_targets)
        AND compare_byte_repr(ec_ior.ec_cell_size, '1M')
        AND compare_byte_repr(s_ior.chunk_size, ec_ior.ec_cell_size)
        AND compare_byte_repr(ec_ior.chunk_size, ec_data_cells(ec_ior.oclass) * byte_repr_to_int(ec_ior.ec_cell_size))
        AND compare_byte_repr(s_ior.xfer_size, ec_ior.xfer_size)
        AND ((test_case_in LIKE '%easy%' AND compare_byte_repr(ec_ior.xfer_size, ec_ior.chunk_size))
         OR  (test_case_in LIKE '%hard%'))
        AND s_ior.test_case LIKE test_case_in
        AND ec_ior.test_case LIKE test_case_in
        AND compare_git_hash(s_ior.daos_commit, s_commit_in)
        AND compare_git_hash(ec_ior.daos_commit, ec_commit_in)
      ORDER BY ec_ior.daos_commit, ec_ior.oclass, ec_ior.num_servers, ec_ior.num_clients;
  END //
DELIMITER ;


DELIMITER //
CREATE OR REPLACE PROCEDURE compare_mdtest_s_ec (
  IN test_case_in TEXT,
  IN ec_oclass_in TEXT,
  IN s_commit_in TEXT,
  IN ec_commit_in TEXT
)
 BEGIN
    IF ec_oclass_in IS NULL THEN SET ec_oclass_in := '%'; END IF;
    IF s_commit_in IS NULL THEN SET s_commit_in := '%'; END IF;
    IF ec_commit_in IS NULL THEN SET ec_commit_in := '%'; END IF;

    SELECT s_mdt.slurm_job_id           AS "S slurm_job_id",
           ec_mdt.slurm_job_id          AS "EC slurm_job_id",
           s_mdt.daos_commit            AS "S Commit",
           ec_mdt.daos_commit           AS "EC Commit",
           s_mdt.oclass                 AS "S Oclass",
           s_mdt.dir_oclass             AS "S Dir Oclass",
           ec_mdt.oclass                AS "EC Oclass",
           ec_mdt.dir_oclass            AS "EC Dir Oclass",
           s_mdt.num_servers            AS "#Servers",
           s_mdt.num_clients            AS "#Clients",
           round(s_mdt.create_kops, 2)  AS "S create_kops",
           round(ec_mdt.create_kops, 2) AS "EC create_kops",
           round(s_mdt.stat_kops, 2)    AS "S stat_kops",
           round(ec_mdt.stat_kops, 2)   AS "EC stat_kops",
           round(s_mdt.read_kops, 2)    AS "S read_kops",
           round(ec_mdt.read_kops, 2)   AS "EC read_kops",
           round(s_mdt.remove_kops, 2)  AS "S remove_kops",
           round(ec_mdt.remove_kops, 2) AS "EC remove_kops",
           percent_diff_fm(s_mdt.create_kops, ec_mdt.create_kops, 2) AS "create%",
           percent_diff_fm(s_mdt.stat_kops, ec_mdt.stat_kops, 2)     AS "stat%",
           percent_diff_fm(s_mdt.read_kops, ec_mdt.read_kops, 2)     AS "read%",
           percent_diff_fm(s_mdt.remove_kops, ec_mdt.remove_kops, 2) AS "remove%"
    FROM results_mdtest ec_mdt JOIN results_mdtest s_mdt
      USING (num_servers, num_clients, num_targets)
      WHERE s_mdt.id != ec_mdt.id
        AND ec_mdt.oclass LIKE ec_oclass_in
        AND s_mdt.oclass = equivalent_oclass_S(ec_mdt.oclass, ec_mdt.num_servers, ec_mdt.num_targets)
        AND compare_byte_repr(s_mdt.chunk_size, '1M')
        AND compare_byte_repr(ec_mdt.chunk_size, ec_data_cells(ec_mdt.oclass) * byte_repr_to_int('1M'))
        AND compare_byte_repr(s_mdt.bytes_write, ec_mdt.bytes_write)
        AND compare_byte_repr(s_mdt.bytes_read, ec_mdt.bytes_read)
        AND s_mdt.test_case LIKE test_case_in
        AND ec_mdt.test_case LIKE test_case_in
        AND compare_git_hash(s_mdt.daos_commit, s_commit_in)
        AND compare_git_hash(ec_mdt.daos_commit, ec_commit_in)
      ORDER BY ec_mdt.daos_commit, ec_mdt.oclass, ec_mdt.num_servers, ec_mdt.num_clients;
  END //
DELIMITER ;


DELIMITER //
CREATE OR REPLACE PROCEDURE compare_mdtest (
  IN test_case_in TEXT,
  IN oclass1_in TEXT,
  IN oclass2_in TEXT,
  IN daos_commit1_in TEXT,
  IN daos_commit2_in TEXT,
  IN subtype_in TEXT
)
 BEGIN
    IF oclass1_in IS NULL THEN SET oclass1_in := '%'; END IF;
    IF oclass2_in IS NULL THEN SET oclass2_in := '%'; END IF;
    IF daos_commit1_in IS NULL THEN SET daos_commit1_in := '%'; END IF;
    IF daos_commit2_in IS NULL THEN SET daos_commit2_in := '%'; END IF;

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
        AND ((subtype_in IS NULL)
          OR (subtype_in = '1to4' AND mdtest1.num_clients = (mdtest1.num_servers * 4))
          OR (subtype_in = 'c16' AND mdtest1.num_clients = 16))
        AND mdtest1.oclass LIKE oclass1_in
        AND mdtest2.oclass LIKE oclass2_in
        AND mdtest1.test_case LIKE test_case_in
        AND mdtest2.test_case LIKE test_case_in
        AND compare_git_hash(mdtest1.daos_commit, daos_commit1_in)
        AND compare_git_hash(mdtest2.daos_commit, daos_commit2_in)
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
    CALL compare_mdtest(test_case_in, oclass1_in, oclass2_in, daos_commit1_in, daos_commit2_in, '1to4');
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
    CALL compare_mdtest(test_case_in, oclass1_in, oclass2_in, daos_commit1_in, daos_commit2_in, 'c16');
  END //
DELIMITER ;


DELIMITER //
CREATE OR REPLACE PROCEDURE show_rebuild (
  IN daos_commit_in TEXT
)
 BEGIN
    IF daos_commit_in IS NULL THEN SET daos_commit_in := '%'; END IF;

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
           rebuild.status                                 AS "Status"
    FROM results_rebuild rebuild
      WHERE compare_git_hash(rebuild.daos_commit, daos_commit_in)
      ORDER BY rebuild.daos_commit, rebuild.num_servers, rebuild.num_pools, rebuild.pool_size, rebuild.num_targets;
  END //
DELIMITER ;
