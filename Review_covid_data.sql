use covid
go

/* quick sanity checks of data
select top 100 * from dbo.Deaths
where date > '11/1/2023'


select top 100 * from tmp.VaxLoad


select top 500 _record_number, 
       iso_code, Location, date, total_cases, new_cases, total_deaths, population
From dbo.Deaths
order by Location, date -- _record_number
*/

-- Compare the cases diagnosed vs deaths
use covid
go 

select top 500 _record_number, 
       iso_code, Location, continent, date, total_cases, total_deaths, 
       (cast(total_deaths as float)/total_cases)*100 as deaths_per_cases
From dbo.Deaths
where continent is Not NULL
  and iso_code in ('CAN', 'USA')
order by date, Location -- _record_number

select Location, date, (cast(total_deaths as float) / population) * 100 [deaths / pop],
       population, total_deaths 
from dbo.Deaths
where continent is Not NULL
order by Location, date -- _record_number


use covid
go

-- LET'S BREAK THINGS DOWN BY CONTINENT
-- 37:30 minutes
select continent, 
       max(cast(total_deaths as int)) as max_peakdeathcount
from covid.dbo.deaths
-- Where location like '%states%'
where continent is not null
Group by continent
order by max_peakDeathCount desc

-- Continent and country Peak deaths
-- note the tiny percent of deaths for many countries far under a thousandth
--   my guess this is due to lack of reported cases.
select continent, location, 
       max(Total_deaths) as PeakDeaths, -- TotalDeathCount
       format(avg(population), 'e') as avg_pop,
       max(cast(isNull(Total_deaths, 0) as float)) / avg(population) frac_deaths
From covid.dbo.Deaths
-- Where location like '%states%'
where continent is not null
group by continent, location
-- order by continent, TotalDeathCount desc
order by  continent, location


Select continent, date, location, 
       MAX(cast(Total_deaths as int)) as max_PeakDeaths -- max_TotalDeathCount
       -- window 
From covid.dbo.Deaths
-- Where location like '%states%'
where continent is not null
Group by continent, date, location
-- order by continent, TotalDeathCount desc
order by  continent, date, location

-- GLOBAL NUMBERS
select continent, Location, date, total_cases, total_deaths, 
      format( (cast(total_deaths as float)/total_cases), '0.0000 %' ) as DeathPercentage
from covid..Deaths
-- Where location like '%states%'
where continent is not null
and cast(total_deaths as float)/total_cases < 0.0002
order by location, date

-- sumarize ww (world wide), the new cases for each day
select date, sum(new_cases) as ww_new_cases_this_day, 
       sum(new_deaths) as ww_new_deaths_this_day
       -- , total_deaths, (total_deaths/total_cases)*100 as deathpercentage
from covid..deaths
-- where location like '%states%'
where continent is not null
group by date
order by 1

-- deaths per case ww
Select SUM(new_cases) as total_cases, 
       SUM(cast(new_deaths as int)) as total_deaths, 
       SUM(cast(new_deaths as int) )/SUM(New_Cases)*100 as DeathPercentage
From covid..Deaths
-- Where location like '%states%'
where continent is not null
-- Group By date
order by 1,2

-- vax (vaccinations)
select top 1000 * from covid..Vax

-- ---------------------------
-- testing the join
select top 1000 d.location, v.location, d.date, v.date
  from covid..Deaths d 
    join covid..Vax v
      on d.iso_code = v.iso_code
      and d.date = v.date

/* jt 12/4: 
   - Not sure what "total vaccinations" represents.
   - Notice for Canada (iso_code 'CAN') the first none-null 
   total value on 12-14-2020 comes with no new_vaccinations. 
   - I'm guessing maybe these 5 people were vaccinated outside Cacnada?
     in the USA or Germany?
     Another possibility is that it is simply an error, though I would
     guess that is unlikely.
   - Albania has the same thing going on so I am unsure what is 
     going on.
 */
select top 1000 d.continent, d.location, d.iso_code, d.date, 
       d.population, v.new_vaccinations,
       v.total_vaccinations, 
       sum( convert(bigint, v.new_vaccinations) ) 
         over (partition by d.iso_code order by d.iso_code, d.date)
         as rolling_Sum_new_vaccinations
From covid..Deaths d
Join covid..vax v
On d.iso_code = v.iso_code
and d.date = v.date
where d.continent is not null
  and d.iso_code = 'CAN'
order by d.iso_code, d.date;


-- Review the number of vaccinations administered using new vaccines
--   
--   Definitions for field names at https://github.com/owid/covid-19-data/blob/master/public/data/README.md
--     as defined on their github page: 
--     new_vaccinations: "New COVID-19 vaccination doses administered (only calculated for 
--                          consecutive days)"
--     total_vaccinations: "Total number of COVID-19 vaccination doses administered"
--
--   Why is the running sum different than the total_vaccinations? 
--     Example: for Albania on January 12, 2021, the total_vaccinations is 128, but no new
--              vaccinations have yet been entered.
--              and similar for Canada at 12-14-2020
--
--     Status: Looking online I don't see anything.
--         I supect it has something to do with consecutive days but not counting new
--         vaccines if the prior day did not have any seems unlikely.
--         Our World in Data does not elaborate about that I can see.
--         It might be syncing the numbers was not a priority and discrepencies were 
--         considered minor.
--   
--   uses window function
select top 200 d.continent, d.location, d.iso_code, d.date, 
       d.population, v.new_vaccinations,
       v.total_vaccinations, 
       sum( cast(v.new_vaccinations as bigint) ) 
         over (partition by d.iso_code order by d.iso_code, d.date) 
         as running_sum_new_vaccinations
  from covid..Deaths d
    join covid..vax v
      on d.iso_code = v.iso_code
     and d.date = v.date 
where d.continent is not null
  and d.iso_code = 'ALB' and d.date >= '2021-01-05'
order by d.location, d.date;


/* Calculate the fraction of population vacinated using new_vaccination
 */
with popvax as (
  select top 1000 d.continent, d.location, d.iso_code, 
         FORMAT (d.date, 'MMM dd yyyy') as date,
         d.population, v.new_vaccinations,
         v.total_vaccinations, 
         sum(cast(v.new_vaccinations as bigint)) 
             over (partition by d.iso_code 
                   order by d.iso_code, d.date) 
         as RuninngSum_vac
    from covid..Deaths d
      join covid..vax v
        on d.iso_code = v.iso_code
       and d.date = v.date 
  where d.continent is not null
    and d.iso_code not in ('AFG')
  order by d.location, d.date      -- Note: I can get away with an order by clause 
                                   --       bcs I did TOP in the select clause.
)
select *, 
       (cast(RuninngSum_vac as float) / population) * 100 as fraction_population_vaccinated,
       format( (cast(RuninngSum_vac as float) / population) * 100, 'P4') as pct_pop_vac
from popvax
;

/*
  Which is faster? in this instance, with > 300 k rows the temporary table was faster

  we could use either a table variable, @popvax, or create a temporary table, #popvax. 
  Unlike the table variable which only exists in the currently 
  executing code block, temporary tables are dropped if
  1. explicitly dropped
  2. the execution completes a stored procedure that create the temporary table
  3. exits the procedure ???
  Other differences are when and how indexs and primary keys are added
  to the two types of tables. Like regular tables primary keys and indexes 
  can be added before or after a temporary table is populated. Table variables 
  keys are added before it is created.

  As of 2018 temporary tables typically preformed better when over 15 k rows.
  In 2023 using SQL Server 2022 on an inexpensive laptop and having >300 k rows.
  Though not appicable in this code, if many inserts and 
  deletes need to be done temporary tables do better.
  Temporary tables can also be truncated but table variables cannot.
  
  The query optimizer doesn't have the benifit of the data before the 
  query is run unless you use the hint, OPTION (RECOMPILE). 

  Here I am just dumping the data to the screen.

  times 2 sec to populate and select the top 1000
 */
use covid
go
select @@version;

select count(*) from covid..vax;

-- for big data sets temporary tables usualy give better performance.
-- we're under a million rows{? check} so not a big set?
declare @popvax table (
  continent nvarchar(50),
  location nvarchar(50),
  date datetime,
  population bigint,
  new_vaccinations int,
  total_vaccinations bigint,
  rollingSumPeopleVaccinated bigint --,
  -- unique(location, date)
)

insert into @popvax(
  continent, location, 
  date, population, new_vaccinations, 
  total_vaccinations, rollingSumPeopleVaccinated
)
select /*top 1000*/ d.continent, d.location, -- d.iso_code, 
        d.date, d.population, v.new_vaccinations,
        v.total_vaccinations, 
        sum(cast(v.new_vaccinations as bigint)) 
            over (partition by d.iso_code 
                  order by d.iso_code, d.date) 
        as RuninngSum_vac
  from covid..Deaths d
    join covid..vax v
      on d.iso_code = v.iso_code
      and d.date = v.date 
where d.continent is not null
--  and d.iso_code not in ('AFG')
OPTION(RECOMPILE);

-- select count(*) from @popvax;

-- select top 1000 * from @popvax;  -- 2 SECONDS

select *, 
       (cast(rollingSumPeopleVaccinated as float) / population) * 100 as fraction_population_vaccinated,
       format( (cast(rollingSumPeopleVaccinated as float) / population) * 100, 'P4') as pct_pop_vac
from @popvax
--  5 SECONDS (3 seconds without the unique index)

go

-- using a temporary table
/*
insert into #popvax(
  continent, location, 
  date, population, new_vaccinations, 
  total_vaccinations, rollingSumPeopleVaccinated
)
*/
DROP TABLE IF exists #popvax;

select /*top 1000*/ d.continent, d.location, -- d.iso_code, 
        d.date, d.population, v.new_vaccinations,
        v.total_vaccinations, 
        sum(cast(v.new_vaccinations as bigint))
            over (partition by d.iso_code 
                  order by d.iso_code, d.date) 
        as rollingSumPeopleVaccinated  -- (RuninngSum_vac)
into #popvax
  from covid..Deaths d
    join covid..vax v
      on d.iso_code = v.iso_code
      and d.date = v.date 
where d.continent is not null
--  and d.iso_code not in ('AFG');
-- OPTION(RECOMPILE);

-- ALTER TABLE dbo.#popvax ADD CONSTRAINT uq_temp_table_popvax UNIQUE(location, date);

-- select count(*) from @popvax;

-- select top 1000 * from @popvax;  -- 2 SECONDS

select top 1000 *, 
       (cast(rollingSumPeopleVaccinated as float) / population) * 100 as fraction_population_vaccinated,
       format( (cast(rollingSumPeopleVaccinated as float) / population) * 100, 'P4') as pct_pop_vac
from #popvax
--  0 SECONDS



DROP TABLE IF exists #popvax;

select top 10 * from #popvax;


/*
 ********* Other ideas **********
 1. Query group deaths by country, month


 */
 use covid
 go

 drop view if exists dbo.rpt_new_vaccinations_totals;
 go

 create view rpt_new_vaccinations_totals as
 with popvax as (
  select d.continent, d.location, d.iso_code, 
         d.date, 
         d.population, v.new_vaccinations,
         v.total_vaccinations, 
         sum(cast(v.new_vaccinations as bigint)) 
             over (partition by d.iso_code 
                   order by d.iso_code, d.date) 
         as RuninngSum_vac
    from covid..Deaths d
      join covid..vax v
        on d.iso_code = v.iso_code
       and d.date = v.date 
  where d.continent is not null
--    and d.iso_code not in ('AFG')
--  order by d.location, d.date      -- Note: I can get away with an order by clause 
                                   --       bcs I did TOP in the select clause.
)
select *, 
       (cast(RuninngSum_vac as float) / population) * 100 as fraction_population_vaccinated,
       format( (cast(RuninngSum_vac as float) / population) * 100, 'P4') as pct_pop_vac
from popvax
;
go

select *,
FORMAT (t.date, 'MMM dd yyyy') as date
from [dbo].[rpt_new_vaccinations_totals] t
where iso_code in ('ABW', 'AFG')
order by iso_code, t.date;

