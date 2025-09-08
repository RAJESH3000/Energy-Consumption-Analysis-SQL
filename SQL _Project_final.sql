CREATE DATABASE ENERGYDB2;
USE ENERGYDB2;


-- 1. country table
CREATE TABLE country (
CID VARCHAR(10) PRIMARY KEY,
Country VARCHAR(100) UNIQUE
);
SELECT * FROM COUNTRY;


-- 2. emission_3 table
CREATE TABLE emission_3 (
country VARCHAR(100),
energy_type VARCHAR(50),
year INT,
emission INT,
per_capita_emission DOUBLE,
FOREIGN KEY (country) REFERENCES country(Country)
);
SELECT * FROM EMISSION_3;



-- 3. population table
CREATE TABLE population (
countries VARCHAR(100),
year INT,
Value DOUBLE,
FOREIGN KEY (countries) REFERENCES country(Country)
);
SELECT * FROM POPULATION;



-- 4. production table
CREATE TABLE production (
country VARCHAR(100),
energy VARCHAR(50),
year INT,
production INT,
FOREIGN KEY (country) REFERENCES country(Country)
);
SELECT * FROM PRODUCTION;


-- 5. gdp_3 table
CREATE TABLE gdp_3 (
Country VARCHAR(100),
year INT,
Value DOUBLE,
FOREIGN KEY (Country) REFERENCES country(Country)
);
SELECT * FROM GDP_3;


-- 6. consumption table
CREATE TABLE consumption (
country VARCHAR(100),
energy VARCHAR(50),
year INT,
consumption INT,
FOREIGN KEY (country) REFERENCES country(Country)
);
SELECT * FROM CONSUMPTION;



-- Data Analysis Questions
-- General & Comparative Analysis


-- 1.  What is the total emission per country for the most recent year available?

select country, year,
 sum(emission) 
 as total_emission
 from EMISSION_3 
where year
 = (select max(year) from EMISSION_3)
group by country, year
 order by total_emission desc;


-- 2. What are the top 5 countries by GDP in the most recent year?

select * from gdp_3 
where year = (select max(year) from gdp_3)
order by value desc limit 5;



-- 3. Compare energy production and consumption by country and year.

SELECT 
    p.country, 
    p.year, 
    sum(p.production) AS total_production,
    sum(c.consumption) AS total_consumption
FROM PRODUCTION p
JOIN CONSUMPTION c 
  ON p.country = c.country 
 AND p.year = c.year
 group by p.country, p.year
 order by p.country, p.year;

-- 4. Which energy types contribute most to emissions across all countries?

SELECT sum(emission) as total_emission, 
energy_type FROM EMISSION_3 
group by energy_type 
order by total_emission desc;


-- Trend Analysis Over Time
-- 1. How have global emissions changed year over year?

with year_total as(select year, sum(EMISSION) 
as total_emission 
from EMISSION_3 
group by year order by year)

select year, total_emission, 
total_emission - lag(total_emission) over(ORDER BY year)
as emission_change
from year_total 
;

-- 2. What is the trend in GDP for each country over the given years?
select country, year, 
s - lag(s) over(partition by country order by year)
 as yearly_gdp_change
from
(select country, year, sum(value) as s
 from gdp_3
 group by country, year 
 )
 as req_table
 order by country , year;


-- 3. How has population growth affected total emissions in each country?

SELECT 
    p.countries, p.year, 
    ROUND(SUM(p.value), 2) AS total_population,
    ROUND(SUM(e.emission) / SUM(p.value), 4)
    AS per_capita_emission
FROM population p 
JOIN emission_3 e 
  ON p.countries = e.country 
 AND p.year = e.year
GROUP BY p.countries, p.year
ORDER BY p.countries, p.year;




-- 4. Has energy consumption increased or decreased over the years for major economies?
WITH top5_countries AS (
    SELECT country
    FROM gdp_3
    GROUP BY country
    ORDER BY SUM(value) DESC
    LIMIT 5
), consumption_diff AS (
    SELECT
        country, year,
        SUM(consumption) AS total_consumption,
        SUM(consumption) - LAG(SUM(consumption))
        OVER (PARTITION BY country ORDER BY year)
        AS yearly_change
    FROM consumption
    WHERE country IN (SELECT country FROM top5_countries)
    GROUP BY country, year
    HAVING year IN (2020, 2023)
)
SELECT
    country, total_consumption, yearly_change,
    CASE
        WHEN yearly_change > 0 THEN 'Increased'
        WHEN yearly_change < 0 THEN 'Decreased'
        ELSE 'No Change'
    END AS result
FROM consumption_diff
WHERE yearly_change IS NOT NULL;




-- 5. What is the average yearly change in emissions per capita for each country?

WITH avg_emission AS (
    SELECT 
        country,
        year,
        AVG(per_capita_emission) AS avg_per_capita
    FROM emission_3
    GROUP BY country, year
),
yearly_diff AS (
    SELECT
        country,
        year,
        avg_per_capita - LAG(avg_per_capita)
        OVER (PARTITION BY country ORDER BY year)
        AS yearly_change
    FROM avg_emission
)
SELECT
    country,
    AVG(yearly_change) AS avg_yearly_change
FROM yearly_diff
WHERE yearly_change IS NOT NULL
GROUP BY country;





-- Ratio & Per Capita Analysis
-- 1. What is the emission-to-GDP ratio for each country by year?

select e. country, e.year,
 sum(e.emission)/ sum(g.value)
 as emission_to_GDP_ratio 
from emission_3 e join gdp_3 g 
on e.country = g.country and e.year = g.year
group by e. country, e.year
order by e. country, e.year;

-- 2. What is the energy consumption per capita for each country over the last decade?
SELECT 
    c.country,
    SUM(c.consumption) AS total_consum,
    ROUND(AVG(p.value), 0) AS avg_pop,
    SUM(c.consumption) / ROUND(AVG(p.value), 0)
    AS consumption_per_capita
FROM consumption c
JOIN population p 
  ON c.country = p.countries
GROUP BY c.country
ORDER BY consumption_per_capita DESC;




-- 3. How does energy production per capita vary across countries?

SELECT 
    p.country, 
    p.year,
    SUM(p.production) AS total_production,
    max(po.value) AS population, 
    SUM(p.production) / MAX(po.value)
    AS per_capita_production
FROM production p
JOIN population po
    ON p.country = po.countries
   AND p.year = po.year
GROUP BY p.country, p.year
ORDER BY per_capita_production DESC;


-- 4. Which countries have the highest energy consumption relative to GDP?

SELECT
    c.country,
    SUM(c.consumption) /SUM(g.value)
    AS consumption_to_gdp_ratio
FROM consumption c
JOIN gdp_3 g
  ON c.country = g.country
 AND c.year = g.year
GROUP BY c.country
ORDER BY consumption_to_gdp_ratio DESC
LIMIT 5;


-- 5. What is the correlation between GDP growth and energy production growth?
-- formual for co - relation
-- (AVG(gdp_growth * energy_growth) - AVG(gdp_growth) * AVG(energy_growth)) /
-- (STDDEV_POP(gdp_growth) * STDDEV_POP(energy_growth))


SELECT 
    (AVG(gdp_growth * energy_growth) - AVG(gdp_growth) * AVG(energy_growth)) /
    (STDDEV_POP(gdp_growth) * STDDEV_POP(energy_growth)) AS correlation
FROM 
(SELECT g.country, g.year, g.gdp_growth, e.energy_growth
    FROM 
    (
        SELECT country, year,
            ((value - LAG(value) OVER (PARTITION BY country ORDER BY year)) / 
             LAG(value) OVER (PARTITION BY country ORDER BY year)) * 100 AS gdp_growth
        FROM gdp_3
    ) g
    JOIN (
        SELECT country, year,
            ((production - LAG(production) OVER (PARTITION BY country ORDER BY year)) /
             LAG(production) OVER (PARTITION BY country ORDER BY year)) * 100 AS energy_growth
        FROM production
    ) e
    ON g.country = e.country AND g.year = e.year
    WHERE g.gdp_growth IS NOT NULL AND e.energy_growth IS NOT NULL
) t;








-- Global Comparisons
-- 1.What are the top 10 countries by population and how do their emissions compare?

SELECT p.countries, 
AVG(p.value) AS avg_pop ,
sum(e.emission) as total_emission
FROM population p join emission_3 e
on p.countries =  e.country
and p.year =  e.year
GROUP BY p.countries
order by avg_pop desc limit 10;

-- 2. Which countries have improved (reduced) their per capita emissions the most over the last decade?
WITH yearly_emission AS (
    SELECT 
        country,
        year,
        SUM(per_capita_emission)
 AS total_per_capita
    FROM emission_3
    WHERE year IN (2020, 2023)
    GROUP BY country, year
),
emission_diff AS (
    SELECT
        country,
        year,
        total_per_capita - LAG(total_per_capita)
        OVER (PARTITION BY country ORDER BY year)
        AS diff
    FROM yearly_emission
)
SELECT country
FROM emission_diff
WHERE diff < 0
ORDER BY diff ASC;




-- 3. What is the global share (%) of emissions by country?

SELECT 
    country,
    ROUND(SUM(emission) * 100.0 / SUM(SUM(emission))
    OVER (), 2) AS global_share_percent
FROM emission_3
GROUP BY country
ORDER BY global_share_percent DESC;



-- 4. What is the global average GDP, emission, and population by year?

-- Step 1: Get all unique country-year combinations
WITH all_country_years AS (
    SELECT country, year FROM gdp_3
    UNION
    SELECT country, year FROM emission_3
    UNION
    SELECT countries AS country,
    year FROM population
)
-- Step 2: Join each dataset to get values
SELECT 
    a.year,
    AVG(g.value) AS global_average_GDP,
    AVG(e.emission) AS global_average_emission,
    AVG(p.value) AS global_average_pop
FROM all_country_years a
LEFT JOIN gdp_3 g
    ON a.country = g.country AND a.year = g.year
LEFT JOIN emission_3 e
    ON a.country = e.country AND a.year = e.year
LEFT JOIN population p
    ON a.country = p.countries AND a.year = p.year
GROUP BY a.year ORDER BY a.year;