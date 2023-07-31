-- 1) Написать функцию, возвращающую таблицу TransferredPoints в более человекочитаемом виде

DROP FUNCTION IF EXISTS fnc_human_readable_transferredpoints();

CREATE
    OR REPLACE FUNCTION fnc_human_readable_transferredpoints()
    RETURNS TABLE
            (
                Peer1        varchar,
                Peer2        varchar,
                PointsAmount bigint
            )
AS
$$
SELECT t1.checkingpeer AS Peer1, t1.checkedpeer AS Peer2, (t1.pointsamount - t2.pointsamount) AS PointsAmount
FROM transferredpoints t1
         JOIN transferredpoints t2
              ON t1.checkingpeer = t2.checkedpeer AND t1.checkedpeer = t2.checkingpeer AND
                 t1.id < t2.id
$$ LANGUAGE sql;

SELECT *
FROM fnc_human_readable_transferredpoints();

-- 2) Написать функцию, которая возвращает таблицу вида: ник пользователя, название проверенного задания, кол-во полученного XP
DROP FUNCTION if EXISTS fnc_peer_get_xp();

CREATE
    OR REPLACE FUNCTION fnc_peer_get_xp()
    RETURNS TABLE
            (
                peer VARCHAR,
                task VARCHAR,
                xp   BIGINT
            )
AS
$$
SELECT checks.peer AS Peer, checks.task AS Task, xp.xpamount AS XP
FROM xp
         JOIN checks ON xp."Check" = checks.id
$$ LANGUAGE SQL;

SELECT *
FROM fnc_peer_get_xp();

-- 3) Написать функцию, определяющую пиров, которые не выходили из кампуса в течение всего дня

DROP FUNCTION IF EXISTS fnc_check_date(peer_date DATE);

CREATE
    OR REPLACE FUNCTION fnc_check_date(peer_date DATE)
    RETURNS TABLE
            (
                peer VARCHAR
            )
AS
$$
SELECT peer
FROM TimeTracking
WHERE "date" = peer_date
GROUP BY peer
HAVING SUM(state) = 1
$$ LANGUAGE SQL;

SELECT *
FROM fnc_check_date('2023-03-02');

SELECT *
FROM fnc_check_date('2023-05-13');

-- 4) Посчитать изменение в количестве пир поинтов каждого пира по таблице TransferredPoints

CREATE
    OR REPLACE FUNCTION fnc_peer_points_change()
    RETURNS TABLE
            (
                Peer   VARCHAR,
                Points BIGINT
            )
AS
$$
SELECT checkingpeer      AS Peer,
       SUM(pointsamount) AS Points
FROM (SELECT checkingpeer, SUM(pointsamount) AS pointsamount
      FROM TransferredPoints
      GROUP BY checkingpeer
      UNION ALL
      SELECT checkedpeer, SUM(-pointsamount) AS pointsamount
      FROM TransferredPoints
      GROUP BY checkedpeer) AS change
GROUP BY checkingpeer
ORDER BY Points DESC;
$$
    LANGUAGE SQL;

SELECT *
FROM fnc_peer_points_change();

-- 5) Посчитать изменение в количестве пир поинтов каждого пира по таблице, возвращаемой первой функцией из Part 3

DROP PROCEDURE if EXISTS fnc_peer_points_change_2(refcursor) CASCADE;

CREATE
    OR REPLACE PROCEDURE fnc_peer_points_change_2(IN curs refcursor)
AS
$$
BEGIN
    OPEN curs FOR
        SELECT "peer1"           AS Peer,
               sum(pointsamount) AS Points
        FROM (SELECT "peer1",
                     SUM("pointsamount") AS pointsamount
              FROM fnc_human_readable_transferredpoints()
              GROUP BY "peer1"
              UNION ALL
              SELECT "peer2",
                     SUM(-"pointsamount") AS pointsamount
              FROM fnc_human_readable_transferredpoints()
              GROUP BY "peer2") AS change
        GROUP BY Peer
        ORDER BY Points DESC;
END
$$
    LANGUAGE plpgsql;

BEGIN;
CALL fnc_peer_points_change_2('curs');
FETCH ALL IN "curs";
END;

-- 6) Определить самое часто проверяемое задание за каждый день

CREATE
    OR REPLACE FUNCTION fnc_frequently_checked_task()
    RETURNS TABLE
            (
                day  DATE,
                task VARCHAR
            )
AS
$$
WITH t1 AS (SELECT "date" AS d, checks.task AS ts, COUNT(task) AS tc
            FROM checks
            GROUP BY ts, d
            ORDER BY d)
SELECT t2.d AS day, t2.ts AS task
FROM (SELECT t1.ts,
             t1.d,
             rank() OVER (PARTITION BY t1.d ORDER BY tc DESC) AS ratingChecked
      FROM t1) AS t2
WHERE ratingChecked = 1
ORDER BY day;
$$
    LANGUAGE sql;

SELECT *
FROM fnc_frequently_checked_task();

-- 7) Найти всех пиров, выполнивших весь заданный блок задач и дату завершения последнего задания

CREATE
    OR replace PROCEDURE completed_block(block_name VARCHAR, curs refcursor)
AS
$$
BEGIN
    OPEN curs FOR
        SELECT peer, to_char(MAX(date), 'DD.MM.YYYY') AS Day
        FROM checks
                 JOIN p2p p
                      ON checks.id = p."Check" AND p.state = 'Success'
        WHERE task IN (SELECT title
                       FROM tasks
                       WHERE title SIMILAR TO concat(block_name
                           , '[0-9]%'))
        GROUP BY peer
        HAVING COUNT(DISTINCT task) = (SELECT COUNT(title)
                                       FROM tasks
                                       WHERE title SIMILAR TO concat('C', '[0-9]%'));
END ;
$$
    LANGUAGE plpgsql;

BEGIN;
CALL completed_block('C', 'curs');
FETCH ALL IN "curs";
END;

-- 8) Определить, к какому пиру стоит идти на проверку каждому обучающемуся

DROP FUNCTION IF EXISTS determine_most_recommend_peer(IN peer VARCHAR, OUT recommendedpeer VARCHAR);

CREATE
    OR REPLACE FUNCTION determine_most_recommend_peer(IN checking_peer VARCHAR)
    RETURNS TABLE
            (
                peer            VARCHAR(30),
                recommendedpeer VARCHAR(30)
            )
AS
$$
BEGIN
    RETURN QUERY WITH find_friends AS (
        SELECT friends.peer2
        FROM friends
        WHERE friends.peer1 = checking_peer
    ),
                      recommended_counts AS (
                          SELECT recommendations.recommendedpeer AS rp, COUNT(*) AS count
                          FROM recommendations
                                   INNER JOIN find_friends ON recommendations.peer = find_friends.peer2
                          WHERE recommendations.recommendedpeer <> checking_peer
                          GROUP BY recommendations.recommendedpeer
                      ),
                      max_recommended AS (
                          SELECT rp
                          FROM recommended_counts
                          WHERE count = (SELECT MAX(count) FROM recommended_counts)
                          LIMIT 1
                      )
                 SELECT checking_peer, rp AS RecommendedPeer
                 FROM max_recommended;

    RETURN;
END;
$$ LANGUAGE plpgsql;


SELECT *
FROM determine_most_recommend_peer('brenettg');

-- 9) Определить процент пиров, которые:
-- Приступили только к блоку 1
-- Приступили только к блоку 2
-- Приступили к обоим
-- Не приступили ни к одному

CREATE
    OR replace PROCEDURE percentage_of_peers_started_block(curs refcursor, block_name1 VARCHAR,
                                                           block_name2 VARCHAR)
AS
$$
BEGIN
    OPEN curs FOR
        WITH started_block1 AS (
            SELECT COUNT(DISTINCT peer) AS t1
            FROM checks c
            WHERE task IN (SELECT title
                           FROM tasks
                           WHERE title similar TO concat(block_name1, '[0-9]%'))),
             started_block2 AS (SELECT COUNT(DISTINCT peer) AS t2
                                FROM checks c
                                WHERE task IN (SELECT title
                                               FROM tasks
                                               WHERE title similar TO concat(block_name2, '[0-9]%'))),
             started_both_blocks AS (SELECT COUNT(*) AS t3
                                     FROM (SELECT DISTINCT peer AS p1
                                           FROM checks c
                                           WHERE task IN (SELECT title
                                                          FROM tasks
                                                          WHERE title similar TO concat(block_name1, '[0-9]%'))) AS r1
                                              JOIN (SELECT DISTINCT peer AS p2
                                                    FROM checks c
                                                    WHERE task IN (SELECT title
                                                                   FROM tasks
                                                                   WHERE title similar TO concat(block_name2, '[0-9]%'))) AS r2
                                                   on r1.p1 = r2.p2),
             started_no_block AS (SELECT COUNT(nickname) AS t4
                                  FROM peers
                                  WHERE nickname NOT IN (
                                      SELECT DISTINCT peer
                                      FROM checks c
                                      WHERE task IN (SELECT title
                                                     FROM tasks
                                                     WHERE title similar TO concat(block_name2, '[0-9]%')))
                                    AND nickname NOT IN (SELECT DISTINCT peer
                                                         FROM checks c
                                                         WHERE task in (SELECT title
                                                                        FROM tasks
                                                                        WHERE title similar TO concat(block_name1, '[0-9]%')))),
             all_peers AS (SELECT COUNT(nickname) AS T FROM peers)
        SELECT round(t1::NUMERIC / T::NUMERIC * 100, 2) AS StartedBlock1,
               round(t2::NUMERIC / T::NUMERIC * 100, 2) AS StartedBlock2,
               round(t3::NUMERIC / T::NUMERIC * 100, 2) AS StartedBothBlocks,
               round(t4::NUMERIC / T::NUMERIC * 100, 2) AS DidntStartAnyBlock
        FROM started_block1,
             started_block2,
             started_both_blocks,
             started_no_block,
             all_peers;
END ;
$$
    LANGUAGE plpgsql;

BEGIN;
CALL percentage_of_peers_started_block('curs', 'C', 'CPP');
FETCH ALL IN "curs";
END;

-- 10) Определить процент пиров, которые когда-либо успешно проходили проверку в свой день рождения

CREATE
    OR replace PROCEDURE percentage_of_peers_passed_tasks_on_birthday(curs refcursor)
AS
$$
BEGIN
    OPEN curs FOR
        WITH successfully_passed AS
                 (SELECT COUNT(c.peer) AS t1
                  FROM checks c
                           JOIN p2p p ON c.id = p."Check" AND p.state = 'Success'
                           JOIN verter v ON c.id = v."Check" AND v.state = 'Success'
                           JOIN peers p2 ON c.peer = p2.nickname AND (SELECT EXTRACT(MONTH FROM p2.birthday))
                      = (SELECT EXTRACT(MONTH from c.date)) AND (SELECT EXTRACT(DAY FROM p2.birthday))
                                                = (SELECT EXTRACT(DAY FROM c.date))),
             failed AS (
                 SELECT COUNT(c.peer) AS t2
                 FROM checks c
                          JOIN p2p p ON c.id = p."Check"
                          JOIN verter v ON c.id = v."Check"
                          JOIN peers p2 ON c.peer = p2.nickname AND (SELECT EXTRACT(MONTH FROM p2.birthday))
                     = (SELECT EXTRACT(MONTH FROM c.date)) AND (SELECT EXTRACT(DAY FROM p2.birthday))
                                               = (SELECT EXTRACT(day from c.date))
                 WHERE (p.state = 'Failure' or v.state = 'Failure')
                   AND (p.state <> 'Start' or v.state = 'Start'))
        SELECT round(t1::NUMERIC / (t1::NUMERIC + t2::NUMERIC) * 100, 2) AS SuccessfulChecks,
               round(t2::NUMERIC / (t1::NUMERIC + t2::NUMERIC) * 100, 2) AS UnsuccessfulChecks
        FROM successfully_passed,
             failed;
END ;
$$
    language plpgsql;

BEGIN;
CALL percentage_of_peers_passed_tasks_on_birthday('curs');
FETCH ALL IN "curs";
END;

-- 11) Определить всех пиров, которые сдали заданные задания 1 и 2, но не сдали задание 3

CREATE
    OR replace PROCEDURE peers_with_finished_tasks(curs REFCURSOR, task1 VARCHAR,
                                                   task2 VARCHAR, task3 VARCHAR)
AS
$$
BEGIN
    OPEN curs FOR
        WITH peers_who_finished_task1 AS
                 (SELECT c.peer
                  FROM checks c
                           JOIN p2p p ON c.id = p."Check" AND p.state = 'Success'
                           JOIN verter v ON c.id = v."Check" AND v.state = 'Success'
                  WHERE c.task = task1),
             peers_who_finished_task2 AS
                 (SELECT c.peer
                  FROM checks c
                           JOIN p2p p ON c.id = p."Check" AND p.state = 'Success'
                           JOIN verter v ON c.id = v."Check" AND v.state = 'Success'
                  WHERE c.task = task2),
             peers_who_finished_task3 AS
                 (SELECT c.peer
                  FROM checks c
                           JOIN p2p p ON c.id = p."Check" AND p.state = 'Success'
                           JOIN verter v ON c.id = v."Check" AND v.state = 'Success'
                  WHERE c.task = task3)
        SELECT t1.peer
        FROM peers_who_finished_task1 t1,
             peers_who_finished_task2 t2,
             peers_who_finished_task3 t3
        WHERE t1.peer = t2.peer
          AND t1.peer <> t3.peer
          AND t2.peer <> t3.peer;
END ;
$$
    LANGUAGE plpgsql;

BEGIN;
CALL peers_with_finished_tasks('curs', 'C2_SimpleBashUtils', 'C6_s21_matrix',
                               'C3_s21_string+');
FETCH ALL IN "curs";
END;

-- 12) Используя рекурсивное обобщенное табличное выражение, для каждой задачи
-- вывести кол-во предшествующих ей задач

DROP FUNCTION IF EXISTS output_number_of_preceding_task();

CREATE OR REPLACE FUNCTION output_number_of_preceding_task()
    RETURNS TABLE
            (
                task      varchar(30),
                prevcount integer
            )
AS
$$
WITH RECURSIVE TaskHierarchy AS (
    SELECT Title, 0 AS PrecedingTasks
    FROM Tasks
    WHERE ParentTask IS NULL
    UNION ALL
    SELECT Tasks.Title, TaskHierarchy.PrecedingTasks + 1
    FROM Tasks
             INNER JOIN TaskHierarchy ON Tasks.ParentTask = TaskHierarchy.Title
)
SELECT Title, PrecedingTasks
FROM TaskHierarchy;
$$ LANGUAGE SQL;


SELECT *
FROM output_number_of_preceding_task();

-- 13) Найти "удачные" для проверок дни. День считается "удачным", если
-- в нем есть хотя бы N идущих подряд успешных проверки

CREATE
    OR REPLACE PROCEDURE find_successful_check_days(IN N int, IN ref refcursor) AS
$$
BEGIN
    OPEN ref FOR
        WITH succsesTables AS (SELECT *
                               FROM checks
                                        JOIN p2p ON checks.id = p2p."Check"
                                        LEFT JOIN verter ON checks.id = verter."Check"
                                        JOIN tasks ON checks.task = tasks.title
                                        JOIN xp ON checks.id = xp."Check"
                               WHERE p2p.state = 'Success'
                                 AND xp.xpamount >= tasks.maxxp * 0.8
                                 AND (verter.state = 'Success' OR verter.state IS NULL)
                                 AND (xp.xpamount >= tasks.maxxp))
        SELECT date
        FROM succsesTables
        GROUP BY date
        HAVING COUNT(date) >= N
        ORDER BY date;
END;
$$
    LANGUAGE plpgsql;

BEGIN;
CALL find_successful_check_days(2, 'ref');
FETCH ALL IN "ref";
END;

-- 14) Определить пира с наибольшим количеством XP

CREATE
    OR replace PROCEDURE prc_get_peer_with_max_xp(curs refcursor) AS
$$
BEGIN
    OPEN curs FOR
        SELECT peer, sum(xp) AS xp
        FROM fnc_peer_get_xp()
        GROUP BY peer
        ORDER BY xp DESC
        limit 1;
END ;
$$
    LANGUAGE plpgsql;

BEGIN;
CALL prc_get_peer_with_max_xp('curs');
FETCH ALL IN "curs";
END;

-- 15) Определить пиров, приходивших раньше заданного времени не менее N раз за всё время

CREATE
    OR replace PROCEDURE prc_peers_came_early_N_times(curs refcursor, var_time time, N_times int)
AS
$$
BEGIN
    OPEN curs FOR
        SELECT peer
        FROM timetracking
        WHERE state = 1
          AND time
            < var_time
        GROUP BY peer
        HAVING COUNT(peer) <= N_times;
END ;
$$
    LANGUAGE plpgsql;

BEGIN;
CALL prc_peers_came_early_N_times('curs', '12:00:00', 1);
FETCH ALL IN "curs";
END;

-- 16) Определить пиров, выходивших за последние N дней из кампуса больше M раз

CREATE
    or replace procedure prc_peers_exited_M_times(curs refcursor, N_days int, M_times int)
AS
$$
BEGIN
    OPEN curs FOR
        SELECT peer
        FROM timetracking
        WHERE state = 2
          AND (SELECT extract(DAY FROM DATE)) >= (SELECT extract(DAY FROM current_date)) - N_days
          AND (SELECT extract(MONTH FROM DATE)) = (SELECT extract(MONTH FROM current_date))
          AND (SELECT extract(YEAR FROM DATE)) = (SELECT extract(YEAR FROM current_date))
        GROUP BY peer
        HAVING count(peer) >= M_times;
END ;
$$
    LANGUAGE plpgsql;

BEGIN;
CALL prc_peers_exited_M_times('curs', 7, 1);
FETCH ALL IN "curs";
END;

BEGIN;
CALL prc_peers_exited_M_times('curs', 14, 2);
FETCH ALL IN "curs";
END;

-- 17) Определить для каждого месяца процент ранних входов

CREATE
    OR replace PROCEDURE early_entries_for_each_month(curs refcursor)
AS
$$
BEGIN
    OPEN curs FOR
        SELECT to_char(m.date, 'Month') AS MONTH,
               (CASE
                    WHEN COUNT(peer) != 0 then
                        ((COUNT(peer) filter (WHERE time < '12:00:00') / COUNT(peer)::float) * 100)::int
                    ELSE
                        0
                   END)                 AS EarlyEntries
        FROM (SELECT '2023-01-01':: date + interval '1' month * d
                         AS date
              FROM generate_series(0, 11) as d) as m
                 LEFT JOIN peers p
                           ON (SELECT EXTRACT(month FROM m.date)) =
                              (SELECT EXTRACT(month FROM p.birthday))
                 LEFT JOIN (
            SELECT peer, date, time
            FROM timetracking
            WHERE state = 1) AS entrances
                           ON p.nickname = entrances.peer
        GROUP BY m.date
        ORDER BY m.date;
END ;
$$
    LANGUAGE plpgsql;

BEGIN;
CALL early_entries_for_each_month('curs');
FETCH ALL IN "curs";
END;