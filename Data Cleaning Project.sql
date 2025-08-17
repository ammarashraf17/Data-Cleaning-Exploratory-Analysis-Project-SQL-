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