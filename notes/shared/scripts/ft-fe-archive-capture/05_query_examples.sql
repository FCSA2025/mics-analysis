-- =============================================================================
-- 05_query_examples.sql
-- Example queries showing how to link TT (results) archives with FT/FE (source)
-- archives to get a complete picture of a TSIP run.
-- =============================================================================

USE [YourDatabase];
GO

-- =============================================================================
-- Query 1: Get all data for a specific TSIP run
-- =============================================================================
-- The TT_PARM archive contains proname (TS PDF) and envname (ES PDF) which
-- link to the FT and FE archives.

DECLARE @RunKey NVARCHAR(128) = 'myproj_run01';  -- Change to your run key

-- Get the run parameters (includes proname/envname links)
SELECT 
    ArchiveId,
    RunKey,
    proname AS TS_PdfName,
    envname AS ES_PdfName,
    runname,
    numcases,
    ArchivedAt
FROM tsip_archive.ArchiveTT_PARM 
WHERE RunKey = @RunKey;
GO

-- =============================================================================
-- Query 2: Get TS source data for a run (via proname)
-- =============================================================================

DECLARE @RunKey NVARCHAR(128) = 'myproj_run01';

-- Join to get TS source sites for this run
SELECT 
    p.RunKey,
    p.ArchivedAt AS RunArchivedAt,
    ft.PdfName AS TS_PdfName,
    ft.call1,
    ft.call2,
    ft.name1,
    ft.latit,
    ft.longit,
    ft.ArchivedAt AS SourceArchivedAt
FROM tsip_archive.ArchiveTT_PARM p
INNER JOIN tsip_archive.ArchiveFT_SITE ft 
    ON ft.PdfName = RTRIM(p.proname)
WHERE p.RunKey = @RunKey;
GO

-- =============================================================================
-- Query 3: Get ES source data for a run (via envname)
-- =============================================================================

DECLARE @RunKey NVARCHAR(128) = 'myproj_run01';

-- Join to get ES source sites for this run
SELECT 
    p.RunKey,
    p.ArchivedAt AS RunArchivedAt,
    fe.PdfName AS ES_PdfName,
    fe.location,
    fe.name,
    fe.latit,
    fe.longit,
    fe.rainzone,
    fe.ArchivedAt AS SourceArchivedAt
FROM tsip_archive.ArchiveTT_PARM p
INNER JOIN tsip_archive.ArchiveFE_SITE fe 
    ON fe.PdfName = RTRIM(p.envname)
WHERE p.RunKey = @RunKey;
GO

-- =============================================================================
-- Query 4: Complete run summary with all source and result counts
-- =============================================================================

DECLARE @RunKey NVARCHAR(128) = 'myproj_run01';

SELECT 
    p.RunKey,
    p.ArchivedAt AS RunArchivedAt,
    RTRIM(p.proname) AS TS_PdfName,
    RTRIM(p.envname) AS ES_PdfName,
    p.numcases AS TotalCases,
    -- TT result counts
    (SELECT COUNT(*) FROM tsip_archive.ArchiveTT_SITE WHERE RunKey = p.RunKey) AS TT_Sites,
    (SELECT COUNT(*) FROM tsip_archive.ArchiveTT_ANTE WHERE RunKey = p.RunKey) AS TT_Antennas,
    (SELECT COUNT(*) FROM tsip_archive.ArchiveTT_CHAN WHERE RunKey = p.RunKey) AS TT_Channels,
    -- FT source counts (TS PDF)
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFT_SITE WHERE PdfName = RTRIM(p.proname)) AS FT_Sites,
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFT_ANTE WHERE PdfName = RTRIM(p.proname)) AS FT_Antennas,
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFT_CHAN WHERE PdfName = RTRIM(p.proname)) AS FT_Channels,
    -- FE source counts (ES PDF)
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFE_SITE WHERE PdfName = RTRIM(p.envname)) AS FE_Sites,
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFE_ANTE WHERE PdfName = RTRIM(p.envname)) AS FE_Antennas,
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFE_CHAN WHERE PdfName = RTRIM(p.envname)) AS FE_Channels
FROM tsip_archive.ArchiveTT_PARM p
WHERE p.RunKey = @RunKey;
GO

-- =============================================================================
-- Query 5: Find all runs that used a specific TS or ES PDF
-- =============================================================================

-- Find runs that used a specific TS file
SELECT RunKey, ArchivedAt, numcases
FROM tsip_archive.ArchiveTT_PARM
WHERE RTRIM(proname) = 'test_ts_pdf';

-- Find runs that used a specific ES file
SELECT RunKey, ArchivedAt, numcases
FROM tsip_archive.ArchiveTT_PARM
WHERE RTRIM(envname) = 'test_es_pdf';
GO

-- =============================================================================
-- Query 6: Get interference results with source station details
-- =============================================================================
-- This joins TT_CHAN results with FT_SITE source data to show the actual
-- station names and locations for interferer/victim pairs.

DECLARE @RunKey NVARCHAR(128) = 'myproj_run01';

SELECT 
    c.caseno,
    -- Interferer details
    c.intcall1,
    int_site.name1 AS InterfererName,
    int_site.latit AS IntLatit,
    int_site.longit AS IntLongit,
    -- Victim details
    c.viccall1,
    vic_site.name1 AS VictimName,
    vic_site.latit AS VicLatit,
    vic_site.longit AS VicLongit,
    -- Results
    c.freqsep,
    c.resti AS Margin_dB
FROM tsip_archive.ArchiveTT_CHAN c
INNER JOIN tsip_archive.ArchiveTT_PARM p ON p.RunKey = c.RunKey
LEFT JOIN tsip_archive.ArchiveFT_SITE int_site 
    ON int_site.PdfName = RTRIM(p.proname) 
    AND int_site.call1 = c.intcall1
LEFT JOIN tsip_archive.ArchiveFT_SITE vic_site 
    ON vic_site.PdfName = RTRIM(p.proname) 
    AND vic_site.call1 = c.viccall1
WHERE c.RunKey = @RunKey
ORDER BY c.caseno;
GO
