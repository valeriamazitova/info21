---------------------create tables---------------------

DROP TABLE IF EXISTS p2p CASCADE;
DROP TABLE IF EXISTS Peers CASCADE;
DROP TABLE IF EXISTS TransferredPoints CASCADE;
DROP TABLE IF EXISTS Friends CASCADE;
DROP TABLE IF EXISTS Recommendations CASCADE;
DROP TABLE IF EXISTS TimeTracking CASCADE;
DROP TABLE IF EXISTS Checks CASCADE;
DROP TABLE IF EXISTS Verter CASCADE;
DROP TABLE IF EXISTS XP CASCADE;
DROP TABLE IF EXISTS Tasks CASCADE;

CREATE TABLE Peers
(
    Nickname VARCHAR NOT NULL PRIMARY KEY,
    Birthday DATE    NOT NULL
);

CREATE TABLE TransferredPoints
(
    ID           BIGINT PRIMARY KEY NOT NULL,
    CheckingPeer VARCHAR            NOT NULL,
    CheckedPeer  VARCHAR            NOT NULL,
    PointsAmount BIGINT             NOT NULL,
    FOREIGN KEY (CheckingPeer) REFERENCES Peers (Nickname),
    FOREIGN KEY (CheckedPeer) REFERENCES Peers (Nickname)
);

CREATE TABLE Friends
(
    ID    BIGINT PRIMARY KEY NOT NULL,
    Peer1 VARCHAR            NOT NULL,
    Peer2 VARCHAR            NOT NULL,
    FOREIGN KEY (Peer1) REFERENCES Peers (Nickname),
    FOREIGN KEY (Peer2) REFERENCES Peers (Nickname)
);

CREATE TABLE Recommendations
(
    ID              BIGINT PRIMARY KEY NOT NULL,
    Peer            VARCHAR            NOT NULL,
    RecommendedPeer VARCHAR            NOT NULL,
    FOREIGN KEY (Peer) REFERENCES Peers (Nickname),
    FOREIGN KEY (RecommendedPeer) REFERENCES Peers (Nickname)
);

CREATE TABLE TimeTracking
(
    ID    BIGINT PRIMARY KEY NOT NULL,
    Peer  varchar            NOT NULL,
    Date  DATE               NOT NULL,
    Time  TIME               NOT NULL,
    State BIGINT             NOT NULL,
    CHECK (State IN (1, 2)),
    FOREIGN KEY (Peer) REFERENCES Peers (Nickname)
);

-- Creating an enumeration for verter
DROP TYPE IF EXISTS check_status CASCADE;
CREATE TYPE check_status AS ENUM ('Start', 'Success', 'Failure');

CREATE TABLE Tasks
(
    Title      VARCHAR NOT NULL PRIMARY KEY,
    ParentTask VARCHAR,
    MaxXP      BIGINT  NOT NULL,
    FOREIGN KEY (ParentTask) REFERENCES Tasks (Title)
);

CREATE TABLE Checks
(
    ID   BIGINT PRIMARY KEY NOT NULL,
    Peer VARCHAR            NOT NULL,
    Task VARCHAR            NOT NULL,
    Date DATE               NOT NULL,
    FOREIGN KEY (Peer) REFERENCES Peers (Nickname),
    FOREIGN KEY (Task) REFERENCES Tasks (Title)
);

CREATE TABLE P2P
(
    ID           BIGINT PRIMARY KEY NOT NULL,
    "Check"      BIGINT             NOT NULL,
    CheckingPeer VARCHAR            NOT NULL,
    State        VARCHAR            NOT NULL,
    Time         TIME               NOT NULL,
    FOREIGN KEY ("Check") REFERENCES Checks (ID),
    FOREIGN KEY (CheckingPeer) REFERENCES Peers (Nickname)
);

CREATE TABLE Verter
(
    ID      BIGINT PRIMARY KEY NOT NULL,
    "Check" BIGINT             NOT NULL,
    State   check_status       NOT NULL,
    Time    TIME               NOT NULL,
    FOREIGN KEY ("Check") REFERENCES Checks (ID)
);

CREATE TABLE XP
(
    ID       BIGINT PRIMARY KEY NOT NULL,
    "Check"  BIGINT             NOT NULL,
    XPAmount BIGINT             NOT NULL,
    FOREIGN KEY ("Check") REFERENCES Checks (ID)
);

----------------initialization tables-----------------

INSERT INTO peers
VALUES ('brenettg', '2012-03-07'),
       ('carrjohn', '2012-02-18'),
       ('halfempt', '2012-08-04'),
       ('utheryde', '2012-01-04'),
       ('aqualadt', '2012-01-05'),
       ('pamalamo', '2012-01-17'),
       ('gulianbo', '2012-02-12'),
       ('annabelw', '2012-10-01'),
       ('sheritsh', '2012-01-25');

INSERT INTO Tasks
VALUES ('C2_SimpleBashUtils', NULL, 250),
       ('C3_s21_string+', 'C2_SimpleBashUtils', 500),
       ('C4_s21_math', 'C2_SimpleBashUtils', 300),
       ('C5_s21_decimal', 'C2_SimpleBashUtils', 350),
       ('C6_s21_matrix', 'C5_s21_decimal', 200),
       ('C7_s21_3D_Viewer', 'C6_s21_matrix', 750),
       ('CPP1_s21_matrixplus', 'C7_s21_3D_Viewer', 200),
       ('CPP2_s21_containers', 'CPP1_s21_matrixplus', 350),
       ('CPP3_s21_SmartCalc', 'CPP2_s21_containers', 500);

INSERT INTO Checks
VALUES (1, 'brenettg', 'C2_SimpleBashUtils', '2023-02-01'),
       (2, 'carrjohn', 'C2_SimpleBashUtils', '2023-02-06'),
       (3, 'halfempt', 'C2_SimpleBashUtils', '2023-02-06'),
       (4, 'aqualadt', 'C4_s21_math', '2023-02-06'),
       (5, 'carrjohn', 'C6_s21_matrix', '2023-02-18'),
       (6, 'utheryde', 'C6_s21_matrix', '2023-04-20'),
       (7, 'brenettg', 'C6_s21_matrix', '2023-04-22'),
       (8, 'annabelw', 'C3_s21_string+', '2023-05-13'),
       (9, 'utheryde', 'C6_s21_matrix', '2023-05-13'),
       (10, 'carrjohn', 'C5_s21_decimal', '2023-05-13'),
       (11, 'aqualadt', 'C5_s21_decimal', '2023-01-05'),
       (12, 'gulianbo', 'C3_s21_string+', '2023-05-13'),
       (13, 'aqualadt', 'C2_SimpleBashUtils', '2023-05-13'),
       (14, 'aqualadt', 'C3_s21_string+', '2023-05-14'),
       (15, 'aqualadt', 'C6_s21_matrix', '2023-05-14'),
       (16, 'halfempt', 'C3_s21_string+', '2023-08-04'),
       (17, 'aqualadt', 'C7_s21_3D_Viewer', '2023-05-16'),
       (18, 'sheritsh', 'CPP1_s21_matrixplus', '2023-05-17');

INSERT INTO P2P
VALUES (1, 6, 'brenettg', 'Start', '09:00:00'),
       (2, 6, 'brenettg', 'Failure', '10:00:00'),

       (3, 2, 'pamalamo', 'Start', '13:00:00'),
       (4, 2, 'pamalamo', 'Success', '14:00:00'),

       (5, 3, 'aqualadt', 'Start', '22:00:00'),
       (6, 3, 'aqualadt', 'Success', '23:00:00'),

       (7, 4, 'utheryde', 'Start', '15:00:00'),  --verter fail
       (8, 4, 'utheryde', 'Success', '16:00:00'),

       (9, 5, 'halfempt', 'Start', '14:00:00'),
       (10, 5, 'halfempt', 'Success', '15:00:00'),

       (11, 1, 'carrjohn', 'Start', '23:34:00'), -- unfinished p2p check

       (12, 8, 'gulianbo', 'Start', '20:57:00'),
       (13, 8, 'gulianbo', 'Success', '20:57:00'),

       (14, 9, 'pamalamo', 'Start', '20:57:00'),
       (15, 9, 'pamalamo', 'Success', '20:57:00'),

       (16, 10, 'halfempt', 'Start', '12:07:00'),

       (17, 11, 'brenettg', 'Start', '12:09:00'),

       (18, 10, 'halfempt', 'Success', '12:37:00'),

       (19, 11, 'brenettg', 'Success', '12:39:00'),

       (20, 12, 'aqualadt', 'Start', '12:04:00'),
       (21, 12, 'aqualadt', 'Failure', '12:44:00'),

       (22, 7, 'annabelw', 'Start', '20:57:00'),
       (23, 7, 'annabelw', 'Success', '20:57:00'),

       (24, 13, 'carrjohn', 'Start', '05:11:00'),
       (25, 13, 'carrjohn', 'Success', '05:45:00'),

       (26, 9, 'brenettg', 'Start', '22:23:00'),

       (27, 14, 'annabelw', 'Start', '20:57:00'),
       (28, 14, 'annabelw', 'Success', '21:40:00'),

       (29, 15, 'halfempt', 'Start', '14:35:00'),
       (30, 15, 'halfempt', 'Success', '15:03:00'),

       (31, 16, 'gulianbo', 'Start', '19:38:00'),
       (32, 16, 'gulianbo', 'Success', '21:10:00'),

       (33, 17, 'pamalamo', 'Start', '16:31:00'),
       (34, 17, 'pamalamo', 'Success', '17:50:00');

INSERT INTO Friends
VALUES (1, 'brenettg', 'carrjohn'),
       (2, 'brenettg', 'utheryde'),
       (3, 'aqualadt', 'utheryde'),
       (4, 'carrjohn', 'aqualadt'),
       (5, 'halfempt', 'carrjohn');

INSERT INTO XP
VALUES (1, 2, 100),
       (2, 3, 250),
       (3, 5, 200),
       (4, 1, 250),
       (5, 2, 250),
       (6, 5, 100),
       (7, 3, 250);

INSERT INTO TimeTracking
VALUES (1, 'brenettg', '2023-03-02', '18:20:00', 1),
       (2, 'brenettg', '2023-03-03', '21:10:00', 2),
       (3, 'aqualadt', '2023-04-02', '12:30:00', 1),
       (4, 'aqualadt', '2023-04-02', '20:50:00', 2),
       (5, 'halfempt', '2023-05-02', '10:00:00', 1),
       (6, 'halfempt', '2023-05-02', '12:30:00', 2),
       (8, 'utheryde', '2023-06-22', '04:50:00', 1),
       (7, 'utheryde', '2023-06-22', '15:30:00', 2),
       (9, 'carrjohn', '2023-06-22', '06:20:00', 1),
       (10, 'carrjohn', '2023-06-22', '15:20:00', 2),
       (11, 'aqualadt', '2023-05-13', '13:30:00', 1),
       (12, 'aqualadt', '2023-05-14', '00:50:00', 2),
       (13, 'gulianbo', '2023-05-13', '13:30:00', 1),
       (14, 'gulianbo', '2023-05-14', '00:50:00', 2),
       (15, 'annabelw', '2023-05-10', '16:50:00', 1),
       (16, 'annabelw', '2023-05-10', '17:20:00', 2),
       (17, 'annabelw', '2023-05-10', '18:36:00', 1),
       (18, 'annabelw', '2023-05-10', '22:30:00', 2),
       (19, 'aqualadt', '2023-01-05', '10:06:00', 1),
       (20, 'aqualadt', '2023-01-05', '23:36:00', 2),
       (21, 'pamalamo', '2023-01-29', '08:36:00', 1),
       (22, 'pamalamo', '2023-01-29', '21:10:00', 2),
       (23, 'sheritsh', '2023-01-04', '17:47:00', 1),
       (24, 'sheritsh', '2023-01-05', '05:48:00', 2),
       (25, 'utheryde', '2023-01-27', '16:35:00', 1),
       (26, 'utheryde', '2023-01-27', '20:50:00', 2),
       (27, 'carrjohn', '2023-01-17', '10:36:00', 1),
       (28, 'carrjohn', '2023-01-17', '14:40:00', 2),
       (29, 'carrjohn', '2023-01-17', '15:50:00', 1),
       (30, 'carrjohn', '2023-01-17', '21:48:00', 2),
       (31, 'brenettg', '2023-01-09', '14:30:00', 1),
       (32, 'brenettg', '2023-01-09', '23:48:00', 2),
       (33, 'halfempt', '2023-01-14', '15:15:00', 1),
       (34, 'halfempt', '2023-01-14', '23:16:00', 2);

INSERT INTO Verter (id, "Check", State, Time)
VALUES (1, 2, 'Start', '13:01:00'),
       (2, 2, 'Success', '13:02:00'),

       (3, 3, 'Start', '23:01:00'),
       (4, 3, 'Failure', '23:02:00'),

       (5, 4, 'Start', '16:01:00'),
       (6, 4, 'Failure', '16:02:00'),

       (7, 5, 'Start', '15:01:00'),
       (8, 5, 'Success', '15:02:00'),

       (9, 9, 'Start', '15:03:00'),
       (10, 9, 'Success', '15:03:00'),

       (11, 3, 'Start', '23:00:00'),
       (12, 3, 'Success', '23:00:00'),

       (13, 11, 'Start', '15:02:00'),
       (14, 11, 'Success', '15:05:00'),

       (15, 9, 'Start', '15:03:00'),
       (16, 9, 'Failure', '15:07:00'),

       (17, 16, 'Start', '21:11:00'),
       (18, 16, 'Success', '21:15:00');

INSERT INTO TransferredPoints
VALUES (1, 'brenettg', 'utheryde', 2),
       (2, 'pamalamo', 'carrjohn', 1),
       (3, 'aqualadt', 'halfempt', 1),
       (4, 'utheryde', 'aqualadt', 1),
       (5, 'halfempt', 'carrjohn', 2),
       (6, 'carrjohn', 'aqualadt', 2),
       (7, 'carrjohn', 'brenettg', 1),
       (8, 'gulianbo', 'annabelw', 1),
       (9, 'pamalamo', 'utheryde', 1),
       (10, 'brenettg', 'aqualadt', 1),
       (11, 'aqualadt', 'gulianbo', 1),
       (12, 'annabelw', 'brenettg', 1),
       (13, 'carrjohn', 'pamalamo', 0),
       (14, 'utheryde', 'brenettg', 0),
       (15, 'brenettg', 'pamalamo', 0),
       (16, 'gulianbo', 'brenettg', 0),
       (17, 'halfempt', 'annabelw', 0),
       (18, 'aqualadt', 'utheryde', 0),
       (19, 'carrjohn', 'halfempt', 0),
       (20, 'pamalamo', 'annabelw', 0);

INSERT INTO Recommendations (id, Peer, RecommendedPeer)
VALUES (1, 'halfempt', 'carrjohn'),
       (2, 'aqualadt', 'utheryde'),
       (3, 'brenettg', 'aqualadt'),
       (4, 'utheryde', 'aqualadt'),
       (5, 'carrjohn', 'halfempt'),
       (6, 'brenettg', 'carrjohn'),
       (7, 'brenettg', 'utheryde'),
       (8, 'halfempt', 'brenettg'),
       (9, 'utheryde', 'halfempt'),
       (10, 'utheryde', 'halfempt');

--------------Creating a procedure for exporting data to files----------------
DROP PROCEDURE IF EXISTS export() CASCADE;

CREATE
OR REPLACE PROCEDURE export(IN tablename VARCHAR, IN path TEXT, IN separator CHAR)
AS
$$
BEGIN
EXECUTE format('COPY %s TO ''%s'' DELIMITER ''%s'' CSV HEADER;',
               tablename, path, separator);
END;
$$
LANGUAGE plpgsql;

--------------Creating a procedure for importing data from files----------------
DROP PROCEDURE IF EXISTS import() CASCADE;

CREATE
OR REPLACE PROCEDURE import(IN tablename VARCHAR, IN path TEXT, IN separator CHAR)
AS
$$
BEGIN
EXECUTE format('COPY %s FROM ''%s'' DELIMITER ''%s'' CSV HEADER;',
               tablename, path, separator);
END;
$$
LANGUAGE plpgsql;

----------------------Testing the export procedure--------------------
CALL export('Peers', '/Users/carrjohn/SQL2_Info21_v1.0-1/src/peers.csv', ',');
CALL export('Tasks', '/Users/carrjohn/SQL2_Info21_v1.0-1/src/tasks.csv', ',');
CALL export('Checks', '/Users/carrjohn/SQL2_Info21_v1.0-1/src/checks.csv', ',');
CALL export('P2P', '/Users/carrjohn/SQL2_Info21_v1.0-1/src/p2p.csv', ',');
CALL export('Verter', '/Users/carrjohn/SQL2_Info21_v1.0-1/src/verter.csv', ',');
CALL export('Transferredpoints', '/Users/carrjohn/SQL2_Info21_v1.0-1/src/transferredpoints.csv', ',');
CALL export('Friends', '/Users/carrjohn/SQL2_Info21_v1.0-1/src/friends.csv', ',');
CALL export('Recommendations', '/Users/carrjohn/SQL2_Info21_v1.0-1/src/recommendations.csv', ',');
CALL export('XP', '/Users/carrjohn/SQL2_Info21_v1.0-1/src/xp.csv', ',');
CALL export('Timetracking', '/Users/carrjohn/SQL2_Info21_v1.0-1/src/timetracking.csv', ',');


TRUNCATE TABLE Peers CASCADE;
TRUNCATE TABLE Tasks CASCADE;
TRUNCATE TABLE Checks CASCADE;
TRUNCATE TABLE P2P CASCADE;
TRUNCATE TABLE Verter CASCADE;
TRUNCATE TABLE Transferredpoints CASCADE;
TRUNCATE TABLE Friends CASCADE;
TRUNCATE TABLE Recommendations CASCADE;
TRUNCATE TABLE XP CASCADE;
TRUNCATE TABLE TimeTracking CASCADE;

----------------------Testing the import procedure--------------------
CALL import('Peers', '/Users/carrjohn/SQL2_Info21_v1.0-1/src/peers.csv', ',');
CALL import('Tasks', '/Users/carrjohn/SQL2_Info21_v1.0-1/src/Tasks.csv', ',');
CALL import('Checks', '/Users/carrjohn/SQL2_Info21_v1.0-1/src/checks.csv', ',');
CALL import('P2P', '/Users/carrjohn/SQL2_Info21_v1.0-1/src/p2p.csv', ',');
CALL import('Verter', '/Users/carrjohn/SQL2_Info21_v1.0-1/src/verter.csv', ',');
CALL import('Transferredpoints', '/Users/carrjohn/SQL2_Info21_v1.0-1/src/transferredpoints.csv', ',');
CALL import('Friends', '/Users/carrjohn/SQL2_Info21_v1.0-1/src/friends.csv', ',');
CALL import('Recommendations', '/Users/carrjohn/SQL2_Info21_v1.0-1/src/recommendations.csv', ',');
CALL import('XP', '/Users/carrjohn/SQL2_Info21_v1.0-1/src/xp.csv', ',');
CALL import('Timetracking', '/Users/carrjohn/SQL2_Info21_v1.0-1/src/timetracking.csv', ',');




