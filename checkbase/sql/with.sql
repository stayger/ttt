-------------------------------------------
-- Проверяет наличие файлов бэкапа 
-- на основе: https://github.com/Tavalik/SQL_TScripts
-------------------------------------------
-- НАСТРАИВАЕМЫЕ ПЕРЕМЕННЫЕ
-- База данных проверки
DECLARE @DBName_Check as nvarchar(40);
-- Дата, на котороую собирается цепочка файлов резервных копий, в формате '20160315 12:00:00'							
DECLARE @BackupTime as datetime = GETDATE() -- Получатели сообщений электронной почты, разделенные знаком ";"				
DECLARE @recipients as nvarchar(500) = 'mssql@test.lan' -------------------------------------------
    -- СЛУЖЕБНЫЕ ПЕРЕМЕННЫЕ	
DECLARE @SQLString NVARCHAR(4000)
DECLARE @backupfile varchar(500);
declare @backupname NVARCHAR(500);
declare @backupdate datetime;
DECLARE @physicalName NVARCHAR(500),
    @logicalName NVARCHAR(500)
DECLARE @error as int
DECLARE @subject as NVARCHAR(100)
DECLARE @finalmessage as NVARCHAR(max)
declare @FileExist int
declare @FileMsg as nvarchar(50)
declare @DBStatus int;
-- Создаем курсор для перебора всех баз данных на сервере
DECLARE db_cursor CURSOR FOR(
        SELECT name
        FROM sys.databases
        where name not in ('master', 'tempdb', 'model', 'msdb')
    ) OPEN db_cursor FETCH NEXT
FROM db_cursor INTO @DBName_Check IF OBJECT_ID('tempdb.dbo.#CheckDatabaseFiles') IS NOT NULL DROP TABLE #CheckDatabaseFiles;
    create table #CheckDatabaseFiles(dbname varchar(50), status int)
    -- Перебираем все базы данных и выполняем операцию
    WHILE @@FETCH_STATUS = 0 BEGIN
set @DBstatus = 0;
declare bkf cursor for with BackupFiles as (
        SELECT backupset.name,
            backupset.backup_start_date,
            backupset.checkpoint_lsn,
            backupset.database_backup_lsn,
            backupset.last_lsn,
            backupset.backup_set_uuid,
            backupset.differential_base_guid,
            backupset.[type] as btype,
            backupmediafamily.physical_device_name
        FROM msdb.dbo.backupset AS backupset
            INNER JOIN msdb.dbo.backupmediafamily AS backupmediafamily ON backupset.media_set_id = backupmediafamily.media_set_id
        WHERE backupset.database_name = @DBName_Check
            and backupset.backup_start_date < @BackupTime
            and backupset.is_copy_only = 0 -- флаг "Только резервное копирование"
            and backupset.is_snapshot = 0 -- флаг "Не snapshot"
            and (
                backupset.description is null
                or backupset.description not like 'Image-level backup'
            ) -- Защита от Veeam Backup & Replication
            and device_type <> 7
    ),
    FullBackup as (
        SELECT TOP 1 BackupFiles.name,
            BackupFiles.checkpoint_lsn,
            BackupFiles.database_backup_lsn,
            BackupFiles.last_lsn,
            BackupFiles.backup_start_date,
            BackupFiles.physical_device_name,
            BackupFiles.backup_set_uuid
        FROM BackupFiles
        WHERE btype = 'D'
        ORDER BY backup_start_date DESC
    ),
    -- Найдем последний разностный бэкап
    DiffBackup as (
        SELECT TOP 1 BackupFiles.name,
            BackupFiles.checkpoint_lsn,
            BackupFiles.database_backup_lsn,
            BackupFiles.last_lsn,
            BackupFiles.backup_start_date,
            BackupFiles.physical_device_name
        FROM BackupFiles
            JOIN FullBackup ON BackupFiles.differential_base_guid = FullBackup.backup_set_uuid
        WHERE BackupFiles.btype = 'I'
        ORDER BY BackupFiles.backup_start_date DESC,
            last_lsn desc
    ),
    -- Соберем бэкапы журналов транзакций
    LogBackup as (
        SELECT BackupFiles.name,
            BackupFiles.checkpoint_lsn,
            BackupFiles.database_backup_lsn,
            BackupFiles.last_lsn,
            BackupFiles.backup_start_date,
            BackupFiles.physical_device_name
        FROM BackupFiles
            JOIN FullBackup on BackupFiles.database_backup_lsn = FullBackup.checkpoint_lsn
        WHERE BackupFiles.btype = 'L'
            and BackupFiles.last_lsn >= (
                select max(last_lsn)
                from (
                        select last_lsn
                        from FullBackup
                        union
                        select last_lsn
                        from DiffBackup
                    ) as lsn_table
            )
    ),
    -- Инициируем цикл по объединению всех трех таблиц
    BackupFilesFinal as (
        SELECT name,
            checkpoint_lsn,
            database_backup_lsn,
            last_lsn,
            backup_start_date,
            physical_device_name
        FROM (
                SELECT name,
                    checkpoint_lsn,
                    database_backup_lsn,
                    last_lsn,
                    backup_start_date,
                    physical_device_name
                FROM FullBackup
                UNION ALL
                SELECT name,
                    checkpoint_lsn,
                    database_backup_lsn,
                    last_lsn,
                    backup_start_date,
                    physical_device_name
                FROM DiffBackup
                UNION ALL
                SELECT name,
                    checkpoint_lsn,
                    database_backup_lsn,
                    last_lsn,
                    backup_start_date,
                    physical_device_name
                FROM LogBackup
            ) AS T
    )
SELECT name,
    physical_device_name,
    backup_start_date
FROM BackupFilesFinal
ORDER BY checkpoint_lsn -- Начало цикла
    OPEN bkf;
-- Прочитаем первый элемент цикла, им может быть только полная резервная копия
FETCH bkf INTO @backupname,
@backupfile,
@backupdate;
print @DBName_Check;
IF @@FETCH_STATUS <> 0 begin
set @DBStatus = 5;
print (@@fetch_status);
end
else begin while @@FETCH_STATUS = 0 begin exec Master.dbo.xp_fileexist @backupfile,
@FileExist out if @DBStatus = 0
set @DBStatus = iif(@FileExist = 1, 0, 1) FETCH bkf INTO @backupname,
    @backupfile,
    @backupdate;
end
end CLOSE bkf;
DEALLOCATE bkf;
insert into #CheckDatabaseFiles (dbname, status) values (@DBName_Check, @DBStatus);
    FETCH NEXT
FROM db_cursor INTO @DBName_Check;
END CLOSE db_cursor;
DEALLOCATE db_cursor;