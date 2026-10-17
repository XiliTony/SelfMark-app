INSERT INTO `plugin` (`code`, `name`, `sort`)
SELECT 'quadrant-board', '画板', 1
WHERE NOT EXISTS (SELECT 1 FROM `plugin` WHERE `code` = 'quadrant-board');

INSERT INTO `plugin` (`code`, `name`, `sort`)
SELECT 'pomodoro', '番茄钟', 2
WHERE NOT EXISTS (SELECT 1 FROM `plugin` WHERE `code` = 'pomodoro');
