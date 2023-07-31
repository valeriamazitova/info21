-- Написать процедуру добавления P2P проверки

CREATE
    OR REPLACE PROCEDURE adding_p2p_verification(
    IN nickname_of_the_peer_being_checked VARCHAR,
    IN inspectors_nickname_peer VARCHAR,
    IN task_name TEXT,
    IN p2p_verification_status check_status,
    IN check_time TIME
) AS
$$
--     declare status check_status := 'Start';
declare
    max_id_checks integer := (SELECT MAX(id)
                              FROM checks);
    declare
    max_id_p2p    integer := (SELECT MAX(id)
                              FROM p2p);
BEGIN
    IF
        p2p_verification_status = 'Start' THEN
        IF ((SELECT COUNT(checks.id)
             FROM p2p
                      JOIN checks ON p2p."Check" = checks.id
             WHERE p2p.checkingpeer = inspectors_nickname_peer
               AND checks.peer = nickname_of_the_peer_being_checked
               AND checks.task = task_name) = 1) THEN
            RAISE EXCEPTION 'Добавление записи невозможно. У данной пары пиров имеется незавершенная проверка';
        ELSE
            INSERT INTO checks
            VALUES (max_id_checks + 1, nickname_of_the_peer_being_checked, task_name, CURRENT_DATE);
            INSERT INTO p2p
            VALUES (max_id_p2p + 1, max_id_checks + 1, inspectors_nickname_peer, p2p_verification_status, check_time);
        END IF;
    ELSE
        if (SELECT "Check"
            FROM p2p
                     JOIN checks c ON c.id = p2p."Check"
                AND c.task = task_name
                AND c.peer = nickname_of_the_peer_being_checked
            WHERE p2p.checkingpeer = inspectors_nickname_peer
              AND p2p.state = 'Start') IS NOT NULL THEN
            INSERT INTO p2p
            VALUES (max_id_p2p + 1,
                    (SELECT "Check"
                     FROM p2p
                              JOIN checks c ON c.id = p2p."Check"
                         AND c.task = task_name
                         AND c.peer = nickname_of_the_peer_being_checked
                     WHERE p2p.checkingpeer = inspectors_nickname_peer
                       AND p2p.state = 'Start'),
                    inspectors_nickname_peer,
                    p2p_verification_status,
                    check_time);
        ELSE
            raise EXCEPTION 'Добавление записи со статусом Success/Failure без существования '
                'соответствующей записи со статусом Start';
        END if;
    END IF;
END;
$$
    LANGUAGE plpgsql;

-- Добавление проверки проекта "s21_decimal" для пира "carrjohn" пиром "halfempt"
CALL adding_p2p_verification('carrjohn', 'halfempt',
                             'C5_s21_decimal', 'Start'::check_status, '12:07:00');

CALL adding_p2p_verification('aqualadt', 'brenettg', 'C5_s21_decimal',
                             'Start'::check_status, '12:09:00');

CALL adding_p2p_verification('carrjohn', 'halfempt',
                             'C5_s21_decimal', 'Success'::check_status, '12:37:00');

CALL adding_p2p_verification('aqualadt', 'brenettg', 'C5_s21_decimal',
                             'Success'::check_status, '12:39:00');


-- Добавление записи в таблицу p2p со статусом "Success" или "Failure"
CALL adding_p2p_verification('gulianbo', 'aqualadt', 'C3_s21_string+',
                             'Start'::check_status, '12:04:00');

CALL adding_p2p_verification('gulianbo', 'aqualadt', 'C3_s21_string+',
                             'Failure'::check_status, '12:44:00');

-- Добавление проверки проекта "s21_decimal" для пира "halfempt" пиром "utheryde"
CALL adding_p2p_verification('halfempt', 'utheryde',
                             'C5_s21_decimal', 'Start'::check_status, '12:00:00');
DELETE
FROM p2p
WHERE id = 12;

CALL adding_p2p_verification('brenettg', 'carrjohn',
                             'C2_SimpleBashUtils', 'Success'::check_status, '12:00:00');

-- DELETE FROM p2p WHERE id = 34;
-- Добавление записи в таблицу p2p со статусом "Success" или "Failure"
CALL adding_p2p_verification('halfempt', 'utheryde',
                             'C5_s21_decimal', 'Failure'::check_status, '12:00:00');


-- Написать процедуру добавления проверки Verter'ом

CREATE
    or replace PROCEDURE add_to_verter(nickname VARCHAR, taskName VARCHAR, verterState check_status,
                                       checkTime TIME)
AS
$$
DECLARE
    id_check INTEGER := (SELECT "Check"
                         FROM p2p
                                  JOIN checks
                                       ON checks.id = p2p."Check" AND p2p.state = 'Success'
                                           AND checks.task = taskName
                                           AND checks.peer = nickname
                         ORDER BY p2p.time
                         LIMIT 1);
BEGIN
    if
        id_check IS NOT NULL THEN
        INSERT INTO verter (id, "Check", STATE, TIME)
        VALUES ((SELECT MAX(id) + 1 FROM verter), id_check, verterState, checkTime);
    ELSE
        raise EXCEPTION 'Добавление записи невозможно.'
            'P2P-проверка не завершена или имеет статус Failure';
    END if;
END
$$
    LANGUAGE plpgsql;

-- Add a record to the Verter table (as a check specify the check of the corresponding task with the latest (by time) successful P2P step)

SELECT checks.peer, checks.task, TIME
FROM p2p,
     checks
WHERE TIME = (SELECT MAX(TIME) AS MAX FROM p2p WHERE STATE = 'Success')
  AND "Check" = checks.id;

CALL add_to_verter('halfempt', 'C3_s21_string+', 'Start', '21:11:00');
CALL add_to_verter('halfempt', 'C3_s21_string+', 'Success', '21:15:00');


call add_to_verter('halfempt', 'C2_SimpleBashUtils', 'Start', '23:00:00');
call add_to_verter('halfempt', 'C2_SimpleBashUtils', 'Success', '23:00:00');

-- Добавление проверки проекта "C6_s21_matrix" со статусом "Start". P2P прошла успешно
CALL add_to_verter('carrjohn', 'C6_s21_matrix', 'Start', '15:02:00');
CALL add_to_verter('carrjohn', 'C6_s21_matrix', 'Success', '15:05:00');
-- Добавление проверки проекта "C6_s21_matrix" со статусом "Success" или "Failure". P2P проверка зафейлилась
CALL add_to_verter('utheryde', 'C6_s21_matrix', 'Start', '15:03:00');
CALL add_to_verter('utheryde', 'C6_s21_matrix', 'Failure', '15:07:00');
-- Добавление проверки проекта "C2_SimpleBashUtils" со статусом "Failure". P2P проверка прошла успешно
CALL add_to_verter('carrjohn', 'C2_SimpleBashUtils', 'Failure', '15:03:00');
DELETE
FROM verter
WHERE id = 11;
DELETE
FROM verter
WHERE id = 12;
DELETE
FROM verter
WHERE id = 13;

-- Попытка добавления записи при условии, что p2p проверка еще не завершена
CALL add_to_verter('brenettg', 'C2_SimpleBashUtils', 'Start', '15:03:00');
-- Попытка добавления записи при условии, что нет успешных p2p проверок
CALL add_to_verter('pamalamo', 'C4_s21_math', 'Start', '15:03:00');


-- Написать триггер: после добавления записи со статутом "начало" в таблицу P2P, и
-- зменить соответствующую запись в таблице TransferredPoints

CREATE
    OR replace FUNCTION fnc_trg_changing_p2p_in_transferred_points() RETURNS TRIGGER AS
$$
BEGIN
    if
        (new.state = 'Start') THEN
        if not exists(SELECT *
                      FROM transferredpoints
                               JOIN p2p p ON transferredpoints.checkingpeer = p.checkingpeer
                          AND transferredpoints.checkingpeer = new.checkingpeer
                               JOIN checks ON p."Check" = checks.id AND transferredpoints.checkedpeer = checks.peer)
        THEN
            INSERT INTO transferredpoints
            values ((SELECT MAX(id) + 1 FROM transferredpoints), new.CheckingPeer,
                    (SELECT peer
                     FROM checks
                              JOIN p2p ON checks.id = p2p."Check"
                         AND p2p."Check" = new."Check"), 0);
        END if;
        UPDATE transferredpoints
        SET pointsamount = pointsamount + 1
        WHERE transferredpoints.checkingpeer = NEW.checkingpeer
          AND transferredpoints.checkedpeer
            IN (SELECT checks.peer
                FROM checks
                         JOIN p2p ON p2p."Check" = checks.id
                WHERE state = 'Start'
                  AND NEW."Check" = checks.id);
    END if;
    RETURN NULL;
END ;
$$
    LANGUAGE plpgsql;

CREATE TRIGGER trg_changing_p2p_in_transferred_points
    AFTER INSERT
    ON p2p
    FOR each row
EXECUTE function fnc_trg_changing_p2p_in_transferred_points();

INSERT INTO p2p
VALUES ((SELECT MAX(id) + 1 FROM p2p), 13, 'carrjohn', 'Start'::check_status, '05:11:00');

INSERT INTO p2p
VALUES ((SELECT MAX(id) + 1 FROM p2p), 13, 'carrjohn', 'Success'::check_status, '05:45:00');

INSERT INTO p2p
VALUES ((SELECT MAX(id) + 1 FROM p2p), 9, 'brenettg', 'Start'::check_status, '22:23:00');

-- Написать триггер: перед добавлением записи в таблицу XP, проверить корректность добавляемой записи

CREATE
    OR replace FUNCTION fnc_trg_xp_table_check() RETURNS TRIGGER
AS
$trg_xp_table_check$
BEGIN
    if
        not exists(SELECT maxxp
                   FROM tasks
                            JOIN checks c ON tasks.title = c.task
                   WHERE c.id = new."Check"
                     AND tasks.title = c.task
                     AND maxxp >= new.xpamount) THEN
        raise EXCEPTION 'Количество XP превышает максимальное доступное для проверяемой задачи';
    elseif
        NOT EXISTS(SELECT id
                   FROM p2p
                   WHERE state = 'Success'
                     AND p2p."Check" = new."Check") THEN
        raise EXCEPTION 'Запись ссылается на незаконченную или неуспешную p2p проверку';
    elseif
        not exists((SELECT id
                    FROM verter
                    WHERE state = 'Success'
                      AND verter."Check" = new."Check")) THEN
        raise EXCEPTION 'Запись ссылается на незаконченную или неуспешную verter проверку';
    END if;
    RETURN NULL;
END ;
$trg_xp_table_check$
    LANGUAGE plpgsql;

CREATE TRIGGER trg_xp_table_check
    AFTER INSERT
    ON xp
    FOR EACH ROW
EXECUTE function fnc_trg_xp_table_check();

-- Добавление записи, где все условия выполнены
INSERT INTO xp
VALUES ((SELECT MAX(id) + 1 FROM xp), 5, 100);
-- Добавление записи, где XP превышает допустимое значение
INSERT INTO xp
VALUES ((SELECT MAX(id) + 1 FROM xp), 8, 1000);
-- Добавление записи с незавершенной p2p проверкой
INSERT INTO xp
VALUES ((SELECT MAX(id) + 1 FROM xp), 1, 250);
-- Добавление записи с неуспешной p2p проверкой
INSERT INTO xp
VALUES ((SELECT MAX(id) + 1 FROM xp), 6, 200);
-- Добавление записи с успешной p2p проверкой, но без проверки вертером
INSERT INTO xp
VALUES ((SELECT MAX(id) + 1 FROM xp), 7, 200);
-- Добавление записи с успешной p2p проверкой и неуспешной проверкой вертером
INSERT INTO xp
VALUES ((SELECT MAX(id) + 1 FROM xp), 4, 300);
-- Добавление записи, где все условия выполнены
INSERT INTO xp
VALUES ((SELECT MAX(id) + 1 FROM xp), 3, 250);


