/*
 * To drop the tables, run these statements.
 * WARNING: THIS WILL DELETE ALL DATA IN THE TABLES.
 */
/*
DROP TABLE IF EXISTS results_rebuild;
DROP TABLE IF EXISTS results_mdtest;
DROP TABLE IF EXISTS results_ior;
*/

CREATE TABLE results_ior (
    id           bigint PRIMARY KEY DEFAULT uuid_short(),
    slurm_job_id bigint UNIQUE,
    test_case    varchar(40) NOT NULL,
    start_time   datetime NOT NULL,
    end_time     datetime,
    test_eta_min int GENERATED ALWAYS AS (TIMESTAMPDIFF(MINUTE, start_time, end_time))
                 COMMENT "difference in minutes between start_time and end_time",
    daos_commit  varchar(40) NOT NULL,
    provider     varchar(40) NOT NULL,
    oclass       varchar(40) NOT NULL,
    num_servers  int NOT NULL,
    num_targets  int,
    num_clients  int NOT NULL,
    ppc          int NOT NULL
                 COMMENT "processes per client",
    num_ranks    int GENERATED ALWAYS AS(num_clients * ppc),
    fpp          bool
                 COMMENT "file per process",
    segments     int,
    chunk_size   varchar(40),
    xfer_size    varchar(40),
    block_size   varchar(40),
    ec_cell_size VARCHAR(40),
    iterations   int,
    sw_time      int,
    notes        varchar(400),
    status       varchar(40) NOT NULL
                 COMMENT "pass/fail/etc.",
    write_gib    float,
    read_gib     float
) COMMENT "ior performance results";


CREATE TABLE results_mdtest (
    id           bigint PRIMARY KEY DEFAULT uuid_short(),
    slurm_job_id bigint UNIQUE,
    test_case    varchar(40) NOT NULL,
    start_time   datetime NOT NULL,
    end_time     datetime,
    test_eta_min int GENERATED ALWAYS AS (TIMESTAMPDIFF(MINUTE, start_time, end_time)),
    daos_commit  varchar(40) NOT NULL,
    provider     varchar(40) NOT NULL,
    oclass       varchar(40) NOT NULL,
    dir_oclass   varchar(40) NOT NULL,
    num_servers  int NOT NULL,
    num_targets  int,
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


CREATE TABLE results_rebuild (
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
