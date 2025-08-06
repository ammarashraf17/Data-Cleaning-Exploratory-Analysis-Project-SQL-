DATA CLEANING PROJECT

# Step 1 - Initial Exploration

-- View raw data
SELECT * FROM layoffs;

# Step 2 — Create Staging Table

-- Create an identical staging table for safe modifications
CREATE TABLE layoffs_staging LIKE layoffs;

-- Confirm table creation
SELECT * FROM layoffs_staging;

-- Insert data into staging table
INSERT INTO layoffs_staging
SELECT * FROM layoffs;

# Step 3 — Identify Duplicates

-- Identify duplicates using ROW_NUMBER() for partitioning
SELECT *,
       ROW_NUMBER() OVER (
           PARTITION BY company, industry, total_laid_off, percentage_laid_off, `date`
       ) AS row_num
FROM layoffs_staging;

-- View only duplicates (row_num > 1)
WITH duplicate_CTE AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY company, industry, total_laid_off, percentage_laid_off, `date`, stage, 
                            country, funds_raised_millions
           ) AS row_num
    FROM layoffs_staging
)
SELECT * 
FROM duplicate_CTE
WHERE row_num > 1;

# Step 4 — Remove Duplicates (Safe Method with Staging2 Table)

-- Create new staging table with row_num to help deletion
CREATE TABLE layoffs_staging2 (
  company TEXT,
  location TEXT,
  industry TEXT,
  total_laid_off INT,
  percentage_laid_off TEXT,
  `date` TEXT,
  stage TEXT,
  country TEXT,
  funds_raised_millions INT,
  row_num INT
);

-- Insert data with row numbers
INSERT INTO layoffs_staging2
SELECT *, ROW_NUMBER() OVER (
    PARTITION BY company, industry, total_laid_off, percentage_laid_off, `date`, stage, 
                 country, funds_raised_millions
) AS row_num
FROM layoffs_staging;

-- Delete duplicate rows (row_num > 1)
DELETE FROM layoffs_staging2
WHERE row_num > 1;

# Step 5 — Standardize Text Data

-- Trim spaces in company names
UPDATE layoffs_staging2
SET company = TRIM(company);

-- Standardize industry names: fix inconsistent 'crypto' variants
UPDATE layoffs_staging2
SET industry = 'Crypto'
WHERE industry LIKE 'crypto%';

-- Standardize country names: remove trailing '.'
UPDATE layoffs_staging2
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States.%';

# Step 6 — Fix Data Types

-- Convert date strings to DATE format
UPDATE layoffs_staging2
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

-- Alter column data type to proper DATE
ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;

# Step 7️ — Handle NULL or Blank Values

-- Identify NULL or blank values in key columns
SELECT * FROM layoffs_staging2
WHERE total_laid_off IS NULL AND percentage_laid_off IS NULL;

SELECT * FROM layoffs_staging2
WHERE industry IS NULL OR industry = '';

-- Convert empty industry strings to NULL
UPDATE layoffs_staging2
SET industry = NULL
WHERE industry = '';

-- Fill NULL industry using other rows with same company info
UPDATE layoffs_staging2 t1
JOIN layoffs_staging2 t2 ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL AND t2.industry IS NOT NULL;

# Step 8️ — Remove Irrelevant or Empty Rows

-- Delete rows where total_laid_off and percentage_laid_off are both NULL
DELETE FROM layoffs_staging2
WHERE total_laid_off IS NULL AND percentage_laid_off IS NULL;

# Step 9️ — Drop Unnecessary Columns

-- Drop row_num column after duplicates removed
ALTER TABLE layoffs_staging2
DROP COLUMN row_num;

# Step — Final Clean Data View

-- Final cleaned data
SELECT * FROM layoffs_staging2;

# My Data Cleaning Best Practices (SQL)
-- Work in staging tables to preserve raw/original data.
-- Use ROW_NUMBER() with PARTITION BY to detect and safely remove duplicate rows.
-- Normalize text data using:
	- TRIM() to remove extra spaces.
	- LIKE and UPDATE to standardize inconsistent text (e.g., "crypto" → "Crypto").
--Convert data types when needed:
		- Use STR_TO_DATE() to convert text dates to proper DATE type.
		- Apply ALTER TABLE to update column data types.
-- Use JOIN to fill missing (NULL) values based on valid matching rows.
-- Delete unnecessary rows with NULLs in critical columns.
-- Drop temporary/helper columns (e.g., row_num) after cleaning is complete.

EXPLORATORY DATA ANALYSIS

# Step 1️ — View Cleaned Data
-- Preview final cleaned data

SELECT * FROM layoffs_staging2;

# Step 2 — Key Stats: Max Layoffs and Percentage
-- Highest layoffs and full company layoffs (percentage_laid_off = 1)

SELECT MAX(total_laid_off), MAX(percentage_laid_off)
FROM layoffs_staging2;

-- Companies with 100% layoffs, ordered by most funds raised
SELECT * 
FROM layoffs_staging2
WHERE percentage_laid_off = 1
ORDER BY funds_raised_millions DESC;

# Step 3 — Company-Level Analysis
-- Total layoffs by company

SELECT company, SUM(total_laid_off) AS total_laid_off_sum
FROM layoffs_staging2
GROUP BY company
ORDER BY total_laid_off_sum DESC;

# Step 4 — Date Range of Layoffs
-- Earliest and latest layoff date

SELECT MIN(`date`) AS earliest_date, MAX(`date`) AS latest_date
FROM layoffs_staging2;

# Step 5 — Layoffs by Industry
-- Total layoffs by industry

SELECT industry, SUM(total_laid_off) AS total_laid_off_sum
FROM layoffs_staging2
GROUP BY industry
ORDER BY total_laid_off_sum DESC;

# Step 6 — Layoffs by Country
-- Total layoffs by country

SELECT country, SUM(total_laid_off) AS total_laid_off_sum
FROM layoffs_staging2
GROUP BY country
ORDER BY total_laid_off_sum DESC;

# Step 7— Yearly Layoffs Trend
-- Total layoffs per year

SELECT YEAR(`date`) AS year, SUM(total_laid_off) AS total_laid_off_sum
FROM layoffs_staging2
GROUP BY YEAR(`date`)
ORDER BY year DESC;

# Step 8 — Layoffs by Company Stage
-- Layoffs grouped by company stage

SELECT stage, SUM(total_laid_off) AS total_laid_off_sum
FROM layoffs_staging2
GROUP BY stage
ORDER BY total_laid_off_sum DESC;

# Step 9️ — Monthly Layoffs Trend
-- Layoffs by month (YYYY-MM format)

SELECT SUBSTRING(`date`, 1, 7) AS `MONTH`, SUM(total_laid_off) AS total_laid_off_sum
FROM layoffs_staging2
WHERE SUBSTRING(`date`, 1, 7) IS NOT NULL
GROUP BY `MONTH`
ORDER BY `MONTH` ASC;

# Step 10— Rolling Monthly Layoffs Total
-- Rolling sum of layoffs over time (monthly)

WITH Rolling_total AS (
  SELECT SUBSTRING(`date`, 1, 7) AS `MONTH`, SUM(total_laid_off) AS total_off
  FROM layoffs_staging2
  WHERE SUBSTRING(`date`, 1, 7) IS NOT NULL
  GROUP BY `MONTH`
)
SELECT `MONTH`, total_off,
       SUM(total_off) OVER (ORDER BY `MONTH`) AS rolling_total
FROM Rolling_total;

# Step 11— Yearly Layoffs by Company
-- Total layoffs per company per year

SELECT company, YEAR(`date`) AS year, SUM(total_laid_off) AS total_laid_off_sum
FROM layoffs_staging2
GROUP BY company, YEAR(`date`)
ORDER BY total_laid_off_sum DESC;

# Step 12— Top Layoffs per Year (Ranking)
-- Rank companies by yearly layoffs
WITH company_year AS (
  SELECT 
    company, 
    YEAR(`date`) AS year, 
    SUM(total_laid_off) AS total_laid_off
  FROM layoffs_staging2
  GROUP BY company, YEAR(`date`)
),
company_year_rank AS (
  SELECT 
    *, 
    DENSE_RANK() OVER (PARTITION BY year ORDER BY total_laid_off DESC) AS ranking
  FROM company_year
  WHERE year IS NOT NULL
)
-- View all ranked results
SELECT *
FROM company_year_rank;

# My Exploratory Best Practices (SQL)
-- I analyzed layoffs by company, industry, country, stage, year, and month.
-- I Used aggregate functions: SUM(), MAX(), MIN(), and ranking with DENSE_RANK().
-- Visualized monthly trends and rolling totals for time-series analysis.
