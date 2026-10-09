INSERT INTO `user` (`mobile`, `password`, `username`)
SELECT '13800138001', '$2a$10$zvOalSvBMNl2gntjDVzK1erEfNxx0h0Dvq8lx/JFTMDtVFJ.iCc9C', '联调用户'
WHERE NOT EXISTS (
    SELECT 1 FROM `user` WHERE `mobile` = '13800138001'
);
