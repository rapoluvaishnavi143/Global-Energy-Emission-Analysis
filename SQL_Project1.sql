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
-- 1.What is the total emission per country for the most recent year available?

SELECT country,year,SUM(emission) AS total_emission
FROM emission_3
WHERE year = (SELECT MAX(year) FROM emission_3)
GROUP BY country, year
ORDER BY total_emission DESC;

-- 2.What are the top 5 countries by GDP in the most recent year?
SELECT Country,year,Value AS GDP
FROM gdp_3
WHERE year = (SELECT MAX(year) FROM gdp_3)
ORDER BY Value DESC
LIMIT 5;

-- 3.Compare energy production and consumption by country and year. 
SELECT p.country,p.year,
    SUM(p.production) AS total_production,
    SUM(c.consumption) AS total_consumption
FROM production p
JOIN consumption c 
    ON p.country = c.country AND p.year = c.year
GROUP BY p.country, p.year
ORDER BY p.country, p.year;

-- 4.Which energy types contribute most to emissions across all countries?
SELECT energy_type,SUM(emission) AS total_emission
FROM emission_3
GROUP BY energy_type
ORDER BY total_emission DESC;
--  Trend Analysis Over Time
-- 5. How have global emissions changed year over year?
SELECT year,SUM(emission) AS total_emission
FROM emission_3
GROUP BY year
ORDER BY year

-- 6.What is the trend in GDP for each country over the given years?
SELECT Country,year,Value AS GDP
FROM gdp_3
ORDER BY Country, year;

-- 7.How has population growth affected total emissions in each country?
SELECT e.country,e.year,
    SUM(e.emission) AS total_emission,
    p.Value AS population
FROM emission_3 e
JOIN population p
    ON e.country = p.countries AND e.year = p.year
GROUP BY e.country, e.year, p.Value
ORDER BY e.country, e.year;

-- 8.Has energy consumption increased or decreased over the years for major economies?
SELECT country,year,
    SUM(consumption) AS total_consumption
FROM consumption
GROUP BY country, year
ORDER BY country, year;

-- 9.What is the average yearly change in emissions per capita for each country?
SELECT country,
    AVG(yearly_change) AS avg_yearly_change
FROM (SELECT country,year,
        per_capita_emission,
        per_capita_emission - LAG(per_capita_emission) 
            OVER (PARTITION BY country ORDER BY year) AS yearly_change
    FROM emission_3
) t
WHERE yearly_change IS NOT NULL
GROUP BY country;
-- Ratio & Per Capita Analysis
-- 10.What is the emission-to-GDP ratio for each country by year?
SELECT 
    e.country,
    e.year,
    SUM(e.emission) AS total_emission,
    g.Value AS gdp,
    SUM(e.emission) / g.Value AS emission_gdp_ratio
FROM emission_3 e
JOIN gdp_3 g
    ON e.country = g.Country
    AND e.year = g.year
GROUP BY e.country, e.year, g.Value
ORDER BY e.country, e.year;

-- 11.What is the energy consumption per capita for each country over the last decade?
SELECT 
    c.country,
    c.year,
    SUM(c.consumption) AS total_consumption,
    p.Value AS population,
    SUM(c.consumption) / p.Value AS consumption_per_capita
FROM consumption c
JOIN population p
    ON c.country = p.countries
    AND c.year = p.year
WHERE c.year >= (SELECT MAX(year) - 9 FROM consumption)
GROUP BY c.country, c.year, p.Value
ORDER BY c.country, c.year;

-- 12.How does energy production per capita vary across countries?
SELECT 
    p.country,
    p.year,
    SUM(p.production) AS total_production,
    pop.Value AS population,
    SUM(p.production) / pop.Value AS production_per_capita
FROM production p
JOIN population pop
    ON p.country = pop.countries
    AND p.year = pop.year
GROUP BY p.country, p.year, pop.Value
ORDER BY p.country, p.year;
-- 13.Which countries have the highest energy consumption relative to GDP?
SELECT 
    c.country,
    c.year,
    SUM(c.consumption) AS total_consumption,
    g.Value AS gdp,
    SUM(c.consumption) / g.Value AS consumption_gdp_ratio
FROM consumption c
JOIN gdp_3 g
    ON c.country = g.Country
    AND c.year = g.year
GROUP BY c.country, c.year, g.Value
ORDER BY consumption_gdp_ratio DESC;

-- 14.What is the correlation between GDP growth and energy production growth?
WITH gdp_growth AS (
    SELECT 
        Country,
        year,
        Value - LAG(Value) OVER (PARTITION BY Country ORDER BY year) AS gdp_growth
    FROM gdp_3
),
production_growth AS (
    SELECT 
        country,
        year,
        total_production - LAG(total_production) OVER (PARTITION BY country ORDER BY year) AS production_growth
    FROM (
        SELECT 
            country,
            year,
            SUM(production) AS total_production
        FROM production
        GROUP BY country, year
    ) t
),
combined AS (
    SELECT 
        g.gdp_growth,
        p.production_growth
    FROM gdp_growth g
    JOIN production_growth p
        ON g.Country = p.country AND g.year = p.year
    WHERE g.gdp_growth IS NOT NULL 
      AND p.production_growth IS NOT NULL
)

SELECT 
    (COUNT(*) * SUM(gdp_growth * production_growth) - 
     SUM(gdp_growth) * SUM(production_growth)) /
    SQRT(
        (COUNT(*) * SUM(gdp_growth * gdp_growth) - POWER(SUM(gdp_growth), 2)) *
        (COUNT(*) * SUM(production_growth * production_growth) - POWER(SUM(production_growth), 2))
    ) AS correlation_value
FROM combined;

--  Global Comparisons
-- 15.What are the top 10 countries by population and how do their emissions compare?
WITH latest_population AS (
    SELECT 
        countries,
        year,
        Value,
        RANK() OVER (ORDER BY Value DESC) AS rnk
    FROM population
    WHERE year = (SELECT MAX(year) FROM population)
),
latest_emission AS (
    SELECT 
        country,
        year,
        SUM(emission) AS total_emission
    FROM emission_3
    WHERE year = (SELECT MAX(year) FROM emission_3)
    GROUP BY country, year
)

SELECT 
    p.countries AS country,
    p.Value AS population,
    e.total_emission
FROM latest_population p
JOIN latest_emission e
    ON p.countries = e.country
WHERE p.rnk <= 10
ORDER BY p.Value DESC;

-- 16.Which countries have improved (reduced) their per capita emissions the most over the last decade?
WITH per_capita AS (
    SELECT 
        country,
        year,
        AVG(per_capita_emission) AS per_capita_emission
    FROM emission_3
    GROUP BY country, year
),
latest_year AS (
    SELECT MAX(year) AS max_year FROM emission_3
),
decade_data AS (
    SELECT 
        p.country,
        MAX(CASE WHEN p.year = l.max_year THEN p.per_capita_emission END) AS latest_value,
        MAX(CASE WHEN p.year = l.max_year - 9 THEN p.per_capita_emission END) AS old_value
    FROM per_capita p, latest_year l
    GROUP BY p.country
)

SELECT 
    country,
    old_value,
    latest_value,
    (old_value - latest_value) AS reduction
FROM decade_data
WHERE old_value IS NOT NULL AND latest_value IS NOT NULL
ORDER BY reduction DESC;

-- 17.What is the global share (%) of emissions by country?
SELECT 
    country,
    SUM(emission) AS total_emission,
    (SUM(emission) * 100.0 / 
        (SELECT SUM(emission) FROM emission_3)
    ) AS global_share_percentage
FROM emission_3
GROUP BY country
ORDER BY global_share_percentage DESC;

-- 18.What is the global average GDP, emission, and population by year?
SELECT 
    g.year,
    AVG(g.Value) AS avg_gdp,
    AVG(e.emission) AS avg_emission,
    AVG(p.Value) AS avg_population
FROM gdp_3 g
JOIN emission_3 e 
    ON g.Country = e.country AND g.year = e.year
JOIN population p 
    ON g.Country = p.countries AND g.year = p.year
GROUP BY g.year
ORDER BY g.year;