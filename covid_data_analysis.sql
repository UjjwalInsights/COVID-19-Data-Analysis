-- Retrieve basic information about COVID-19 cases and deaths
SELECT 
    location, 
    date, 
    total_cases, 
    new_cases, 
    total_deaths, 
    population
FROM 
    public.covid_deaths
ORDER BY 
    location, 
    date;

-- Calculate the percentage of total cases compared to population
SELECT 
    location, 
    date, 
    total_cases, 
    ROUND((population / 1000000), 3) AS population_in_millions,
    ROUND((NULLIF(total_cases::numeric / population::numeric, 0)) * 100, 3) AS case_to_population_percentage
FROM 
    public.covid_deaths
WHERE 
    continent IS NOT NULL 
    AND total_cases IS NOT NULL 
ORDER BY 
    location, 
    date;

-- Identify countries with the highest infection rates compared to population
SELECT 
    location, 
    ROUND((population / 1000000), 3) AS population_in_millions, 
    MAX(total_cases) AS highest_infection_count, 
    ROUND(MAX((total_cases / population)) * 100, 4) AS percentage_population_infected
FROM 
    public.covid_deaths
WHERE 
    continent IS NOT NULL 
    AND total_cases IS NOT NULL
GROUP BY 
    location, 
    population 
ORDER BY 
    percentage_population_infected DESC;

-- Identify countries with the highest death count per population
SELECT 
    location, 
    ROUND((population / 1000000), 3) AS population_in_millions, 
    MAX(total_deaths) AS total_death_count, 
    ROUND(MAX((total_deaths / population)) * 100, 4) AS percentage_population_death
FROM 
    public.covid_deaths
WHERE 
    continent IS NOT NULL 
    AND total_deaths IS NOT NULL
GROUP BY 
    location, 
    population 
ORDER BY 
    percentage_population_death DESC;

-- Analyze the total cases vs. total deaths ratio in India
SELECT 
    location, 
    date, 
    total_cases, 
    total_deaths, 
    CASE 
        WHEN total_deaths = 0 THEN NULL 
        ELSE ROUND((total_deaths / total_cases) * 100, 2) 
    END AS cases_deaths_ratio
FROM 
    public.covid_deaths
WHERE 
    continent IS NOT NULL 
    AND location LIKE '%India%'
    AND total_cases IS NOT NULL
ORDER BY 
    date;

-- Analyze the total cases to total death ratio in India and the United States
SELECT 
    location, 
    MAX(total_cases) AS max_total_cases, 
    MAX(total_deaths) AS max_total_deaths, 
    ROUND(MAX(total_deaths) / NULLIF(MAX(total_cases), 0), 4) AS case_to_death_ratio
FROM 
    public.covid_deaths
WHERE 
    continent IS NOT NULL 
    AND (UPPER(location) LIKE '%INDIA%' OR UPPER(location) LIKE '%UNITED STATES')
GROUP BY 
    location;

-- Analyze the total cases to total death ratio of each country
SELECT 
    location,
    MAX(total_cases) AS max_total_cases,
    MAX(total_deaths) AS max_total_deaths,
	ROUND(MAX(total_deaths) / NULLIF(MAX(total_cases), 0), 4) AS max_cases_to_death_ratio
FROM 
    public.covid_deaths
WHERE 
    continent IS NOT NULL 
    AND total_cases IS NOT NULL
    AND total_deaths IS NOT NULL
GROUP BY 
    location
ORDER BY 
    max_cases_to_death_ratio DESC;

-- Break down COVID-19 data by continent
SELECT 
    continent, 
    MAX(total_deaths) AS total_death_count  
FROM 
    public.covid_deaths
WHERE 
    continent IS NOT NULL 
GROUP BY 
    continent
ORDER BY 
    total_death_count DESC;

-- Calculate global COVID-19 statistics

SELECT  
    SUM(new_cases) AS total_cases,
    SUM(CAST(new_deaths AS INT)) AS total_deaths,
    CASE 
        WHEN SUM(new_cases) > 0 THEN ROUND(CAST((SUM(CAST(new_deaths AS NUMERIC)) / SUM(new_cases)) * 100 AS NUMERIC), 3)
        ELSE 0
    END AS death_percentage
FROM 
    public.covid_deaths
WHERE 
    continent IS NOT NULL;



-- Using CTE to perform Calculation on percentage of population that has received at least one COVID-19 vaccine dose


WITH PopvsVac (Continent, Location, Date, Population, New_Vaccinations, RollingPeopleVaccinated) AS (
    SELECT 
        dea.continent, 
        dea.location, 
        dea.date, 
        dea.population, 
        vac.new_vaccinations,
        SUM(CAST(vac.new_vaccinations AS INTEGER)) OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) AS RollingPeopleVaccinated
    FROM 
        public.covid_deaths dea
    JOIN 
        public.covid_vaccinations vac ON dea.location = vac.location AND dea.date = vac.date
    WHERE 
        dea.continent IS NOT NULL
)
SELECT 
    *,
    (RollingPeopleVaccinated::FLOAT / Population) * 100 AS VaccinationPercentage
FROM 
    PopvsVac;

-- Using Temp Table to perform Calculation on Partition By in previous query
-- Drop the temporary table if it exists

DROP TABLE IF EXISTS PercentPopulationVaccinated;

-- Create the temporary table
CREATE TEMP TABLE PercentPopulationVaccinated (
    Continent VARCHAR(255),
    Location VARCHAR(255),
    Date DATE,
    Population NUMERIC,
    New_vaccinations NUMERIC,
    RollingPeopleVaccinated NUMERIC
);

-- Insert data into the temporary table
INSERT INTO PercentPopulationVaccinated
SELECT 
    dea.continent, 
    dea.location, 
    dea.date::DATE,  -- Ensure date format is correct
    dea.population, 
    vac.new_vaccinations,
    SUM(vac.new_vaccinations) OVER (PARTITION BY dea.Location ORDER BY dea.location, dea.Date) AS RollingPeopleVaccinated
FROM 
    public.covid_deaths dea
JOIN 
    public.covid_vaccinations vac ON dea.location = vac.location AND dea.date = vac.date;

-- Retrieve results from the temporary table
SELECT 
    *,
    (RollingPeopleVaccinated / Population) * 100 AS PercentPopulationVaccinated
FROM 
    PercentPopulationVaccinated;


-- Create a view to store data for later visualizations
CREATE VIEW percent_population_vaccinated AS
SELECT 
    dea.continent, 
    dea.location, 
    dea.date, 
    dea.population, 
    vac.new_vaccinations,
    SUM(CAST(vac.new_vaccinations AS INTEGER)) OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) AS rolling_people_vaccinated
FROM 
    public.covid_deaths dea
JOIN  
    public.covid_vaccinations vac ON dea.location = vac.location
                                   AND dea.date = vac.date
WHERE 
    dea.continent IS NOT NULL;
