USE electricity
select MIN(start_date) from price_data
select Top 5 * from demand_price
select Top 5 * from price_data
---Exploring and cleaning the data 
EXEC sp_help demand_data

--There are more than 20 columns, but some of the columns are not relevant
ALTER TABLE demand_data
DROP COLUMN
    "IFA_FLOW", "IFA2_FLOW", "BRITNED_FLOW", "MOYLE_FLOW", "EAST_WEST_FLOW", "NEMO_FLOW", "NSL_FLOW", "ELECLINK_FLOW", "VIKING_FLOW", "GREENLINK_FLOW"

EXEC sp_help demand_data

-- We need to rename some columns for better understanding and change the datatype of settlement date and settement period

SELECT CONVERT(DATE, SETTLEMENT_DATE) FROM demand_data

ALTER TABLE demand_data
ADD demand_date DATE

UPDATE demand_data
SET demand_date = CONVERT(DATE, SETTLEMENT_DATE)

EXEC sp_help demand_data

ALTER TABLE demand_data
DROP COLUMN SETTLEMENT_DATE

EXEC sp_rename 'dbo.demand_data.demand_date', 'SETTLEMENT_DATE', 'COLUMN'
EXEC sp_rename 'dbo.demand_data.ND', 'NATIONAL_DEMAND', 'COLUMN'
EXEC sp_rename 'dbo.demand_data.TSD', 'TRANSMISSION_SYSTEM_DEMAND', 'COLUMN'

-- We know that there is some duplicates as current& forecasted data and historical data for 2026 will have some overlaps
SELECT  MIN(SETTLEMENT_DATE), 
		[SETTLEMENT_PERIOD],  
		[NATIONAL_DEMAND] 
FROM demand_data 
WHERE FORECAST_ACTUAL_INDICATOR IS NOT NULL
GROUP BY [SETTLEMENT_PERIOD],  [NATIONAL_DEMAND]

SELECT  * 
FROM demand_data 
WHERE SETTLEMENT_DATE = (SELECT  MIN(SETTLEMENT_DATE) FROM  demand_data WHERE FORECAST_ACTUAL_INDICATOR IS NOT NULL)

-- We can see a pattern, each date will be repeated 48 times as settlement period is till 48 (30 mins interval so 24 hrs *2 ) so if it is repeated more than than that it is a duplicate entry. Ideally 96 times (48*2)

SELECT SETTLEMENT_DATE, 
		COUNT(*) AS C
FROM demand_data
GROUP BY SETTLEMENT_DATE
HAVING COUNT(*) > 48
ORDER BY SETTLEMENT_DATE

-- Looking at this we can see and understand from 2026, April 01 to 2026 April 18 it is duplicate. But we do not know what is going on with 2024-10-27, and 2025-10-26
SELECT * 
FROM demand_data
WHERE SETTLEMENT_DATE IN ('2024-10-27', '2025-10-26')
-- they are both the dates in october, and only 2 settlement periods are added, that is because of end of British summer time, when clocks go 1 hour backward

SELECT SETTLEMENT_DATE, 
		COUNT(*) AS C
FROM demand_data
GROUP BY SETTLEMENT_DATE
HAVING COUNT(*) > 50
ORDER BY SETTLEMENT_DATE

WITH CTE1 AS 
(
	SELECT SETTLEMENT_DATE, 
			SETTLEMENT_PERIOD, 
			ROW_NUMBER() OVER (PARTITION BY SETTLEMENT_DATE, SETTLEMENT_PERIOD ORDER BY SETTLEMENT_DATE) AS DUPLICATE_ROWS
	FROM demand_data
)
--SELECT * FROM CTE1 WHERE DUPLICATE_ROWS > 1
DELETE FROM CTE1 
WHERE DUPLICATE_ROWS > 1

--THE FOLLOWING DATA IS FROM THE HISTORICAL DATASET, SO WE CAN SAY IT IS ACTUAL
SELECT * FROM demand_data
WHERE FORECAST_ACTUAL_INDICATOR IS NULL

UPDATE demand_data
SET FORECAST_ACTUAL_INDICATOR = 'A' 
WHERE FORECAST_ACTUAL_INDICATOR IS NULL

SELECT * FROM demand_data

--Let us extract the month, year and weekdays name from the data

ALTER TABLE demand_data
ADD DEMAND_YEAR INT, 
DEMAND_MONTH VARCHAR (10), 
WEEKDAY_DEMAND VARCHAR(10)

UPDATE demand_data 
SET DEMAND_YEAR = YEAR(SETTLEMENT_DATE), 
DEMAND_MONTH = FORMAT((SETTLEMENT_DATE), 'MMM'), 
WEEKDAY_DEMAND = DATENAME(weekday, SETTLEMENT_DATE)

SELECT top 5 * FROM demand_data

SELECT format(settlement_date, 'MMM'),DEMAND_MONTH  as mon from demand_data

SELECT TOP 5 * FROM demand_price
EXEC sp_rename 'demand_price', 'price_data'

SELECT Top 5 FROM price_data

EXEC sp_help price_data

-- THE FOLLOWING TABLE SHOWS THAT THE WHOLE COLUMN HAS NULL VALUES
SELECT * from price_data
WHERE payment_method is not null

ALTER TABLE price_data
DROP COLUMN payment_method

ALTER TABLE price_data
DROP COLUMN region_code


ALTER TABLE price_data
ADD start_date DATE,
    end_date DATE


ALTER TABLE price_data
ADD PRICE_YEAR INT,
    PRICE_MONTH VARCHAR(3),
    SETTLEMENT_PERIOD INT

UPDATE price_data
SET 
    start_date = CONVERT(DATE, valid_from),
    end_date = CONVERT(DATE, valid_to),
    PRICE_YEAR = YEAR(CONVERT(DATETIME, valid_from)),
    PRICE_MONTH = FORMAT(CONVERT(DATETIME, valid_from), 'MMM'),
    SETTLEMENT_PERIOD = (DATEPART(HOUR, CONVERT(DATETIME, valid_from)) * 2) + 
                       (CASE WHEN DATEPART(MINUTE, CONVERT(DATETIME, valid_from)) >= 30 THEN 2 ELSE 1 END)

SELECT TOP 5 * from demand_data
SELECT TOP 5 * from price_data

ALTER TABLE price_data
ALTER COLUMN start_date DATE

--- WE have 14 regions / every granual data in octopus but not in neso, so let us standiridise it
SELECT DISTINCT region_name
FROM price_data



SELECT MIN(start_date), MAX(start_date) from price_data
--- this shows there is some issue as from 14M ur records are slased to 1000 records only

SELECT Top 10 start_date, SETTLEMENT_PERIOD, COUNT(*) as Duplicated_Count
FROM price_data
GROUP BY start_date, SETTLEMENT_PERIOD
ORDER BY start_date, SETTLEMENT_PERIOD ASC;

-- this above table confirms that we have total  14000 duplicate records 


SELECT DISTINCT 
        start_date, 
        SETTLEMENT_PERIOD,
        PRICE_YEAR,
        PRICE_MONTH, region_name, 
        value_inc_vat
    FROM price_data
	order by start_date, settlement_period
-- this above table confirms that we have 14000 distinct records (with 14 regions)

SELECT DISTINCT 
    start_date, 
    SETTLEMENT_PERIOD,
    PRICE_YEAR,
    PRICE_MONTH
FROM price_data
GROUP BY start_date, SETTLEMENT_PERIOD, PRICE_YEAR, PRICE_MONTH;




--- i do not want to remove the region in the orignal price_data table, so i will create a new summarised one, which is efficient for joins

SELECT start_date, 
    SETTLEMENT_PERIOD,
    PRICE_YEAR,
    PRICE_MONTH, AVG(value_inc_vat) AS AVG_PRICE_INC_VAT,
	MIN(value_inc_vat) AS MIN_PRICE_INC_VAT, -- though these lows will be on regional level
    MAX(value_inc_vat) AS MAX_PRICE_INC_VAT  -- though these highs will be on regional level
	INTO national_price_data
    FROM price_data
	GROUP BY start_date, SETTLEMENT_PERIOD, PRICE_YEAR, PRICE_MONTH

SELECT TOP 5 * FROM national_price_data

EXEC sp_help  national_price_data

---National price data has 1000 rows which are valid

CREATE VIEW vw_Analysis_Price_Demand AS
SELECT 
    p.start_date AS Settlement_Date,
    p.SETTLEMENT_PERIOD AS Settlement_Period,
    p.PRICE_YEAR AS Price_Year,
    p.PRICE_MONTH AS Price_Month,
    ROUND(p.AVG_PRICE_INC_VAT, 2) AS Avg_Price,
	ROUND(P.MIN_PRICE_INC_VAT, 2) AS Min_Price,
	ROUND(P.MAX_PRICE_INC_VAT, 2) AS Max_Price,
    d.NATIONAL_DEMAND AS National_Demand,
    d.EMBEDDED_WIND_GENERATION AS Wind_Gen,
    d.EMBEDDED_SOLAR_GENERATION AS Solar_Gen,
    d.SCOTTISH_TRANSFER AS Scottish_Transfer,
    CASE 
        WHEN p.SETTLEMENT_PERIOD BETWEEN 1 AND 14 THEN 'Overnight (12am-7am)'
        WHEN p.SETTLEMENT_PERIOD BETWEEN 15 AND 24 THEN 'Morninig (7am-12pm)'
		WHEN p.SETTLEMENT_PERIOD BETWEEN 24 AND 32 THEN 'Daytime (12pm-4pm)'
        WHEN p.SETTLEMENT_PERIOD BETWEEN 33 AND 38 THEN 'Evening (4pm-7pm)'
        ELSE 'Night (7pm-12am)'
    END AS Time_Block
FROM national_price_data AS p
INNER JOIN demand_data AS d 
    ON p.SETTLEMENT_PERIOD = d.SETTLEMENT_PERIOD
    AND p.start_date = d.SETTLEMENT_DATE

SELECT Top 10 * FROM vw_Analysis_Price_Demand

	SELECT Time_Block, Avg_Price From vw_Analysis_Price_Demand
	ORDER BY Avg_Price
	
		SELECT  TOP 10 Settlement_Period, Time_Block, AVG(Avg_Price) AS Avg_Price, AVG(National_Demand ) AS National_demand
			From vw_Analysis_Price_Demand
			GROUP BY Settlement_Period , Time_Block 
			ORDER BY AVG(Avg_Price) ASC
			
			SELECT  Settlement_Period, Time_Block, Avg_Price, National_Demand 
			From vw_Analysis_Price_Demand
			WHERE  Avg_Price < 0 
			ORDER BY Avg_Price ASC

			SELECT  TOP 10 Settlement_Period, 
           Time_Block, 
           AVG(Avg_Price) AS Avg_Price, 
           AVG(National_Demand ) AS National_demand
   From vw_Analysis_Price_Demand
   GROUP BY Settlement_Period , Time_Block 
   ORDER BY AVG(Avg_Price) DESC


		   SELECT  DISTINCT Settlement_Period, Time_Block, (Avg_Price) , Count(time_block) over (partition by Time_Block) AS Freq_Time_Block
			From vw_Analysis_Price_Demand
			WHERE Avg_Price < 0 
			order by Freq_Time_Block DESC


	SELECT MIN(Avg_Price), MAX(avg_price) From vw_Analysis_Price_Demand

--- 12PM TO 4 PM BEST SLOT WHERE YOU CAN EARN FOR CONSUMPTION, OR THE MAXIUMM YOU HAVE TO PAY IS 10 POUNDS :)
With t1 AS 
(
SELECT *, 
    CASE 
        WHEN Avg_Price < 0 THEN '< £0'
        WHEN Avg_Price BETWEEN 0 AND 5 THEN '£0 to £5'
        WHEN Avg_Price > 5 AND Avg_Price <= 10 THEN '(> £5 and <= £10)'
        WHEN Avg_Price > 10 AND Avg_Price <= 15 THEN '(> £10 and <= £15)'
        WHEN Avg_Price > 15 AND Avg_Price <= 20 THEN '(> £15 and <= £20)'
        WHEN Avg_Price > 20 AND Avg_Price <= 25 THEN '(> £20 and <= £25)'
        WHEN Avg_Price > 25 AND Avg_Price <= 30 THEN '(> £25 and <= £30)'
        WHEN Avg_Price > 30 AND Avg_Price <= 35 THEN '(> £30 and <= £35)'
        WHEN Avg_Price > 35 AND Avg_Price <= 42 THEN '(> £35 and <= £42)'
        ELSE '> £42'
    END AS Price_Band
	,(Wind_Gen + Solar_Gen + Scottish_Transfer) AS Total_Renewable_Generation
FROM vw_Analysis_Price_Demand
), t2 AS (
SELECT  DISTINCT
		Time_Block,
		Price_Band 
		, count(*) OVER (PARTITION BY Time_Block , Price_Band) AS Freq_time_block
FROM t1)
SELECT * FROM t2 
WHERE Time_Block = 'Morninig (7am-12pm)' OR Time_Block =  'Daytime (12pm-4pm)'
ORDER BY Time_Block ASC, Freq_time_block DESC

--- lets see how much price changes after each settlement period

With t1 AS 
(
SELECT * , 
	LAG(Avg_Price) OVER ( ORDER BY Settlement_Date, Settlement_Period) AS Prev_Price
FROM vw_Analysis_Price_Demand)
, t2 AS
(
SELECT *, ROUND((Avg_Price - Prev_Price),2) AS Change_in_Price
from t1 )
, t3 AS
(SELECT * ,
	CASE
		WHEN Change_in_Price <= -5 THEN 'Decreased'
		WHEN Change_in_Price > -5 And Change_in_Price <= 5 THEN 'Stable'
		WHEN Change_in_Price > 5 And Change_in_Price <= 10 THEN 'Increased'
		ELSE 'Sudden Spike'
	END AS Price_change_slot
FROM t2)
SELECT *
FROM t3
WHERE Price_change_slot = 'Sudden Spike'

-- its always 31 (3:30 PM) as settlement period where sudden spike has happened



With t1 AS 
(
SELECT * , 
	LAG(Avg_Price) OVER ( ORDER BY Settlement_Date, Settlement_Period) AS Prev_Price
FROM vw_Analysis_Price_Demand)
, t2 AS
(
SELECT *, ROUND((Avg_Price - Prev_Price),2) AS Change_in_Price
from t1 )
, t3 AS
(SELECT * ,
	CASE
		WHEN Change_in_Price <= -5 THEN 'Decreased'
		WHEN Change_in_Price > -5 And Change_in_Price <= 5 THEN 'Stable'
		WHEN Change_in_Price > 5 And Change_in_Price <= 10 THEN 'Increased'
		ELSE 'Sudden Spike'
	END AS Price_change_slot
	, (Wind_Gen + Solar_Gen + Scottish_Transfer) AS Total_Renewable_Generation
FROM t2)
SELECT 
    Settlement_Period,
    Round(Avg(Avg_Price), 0) AS Avg_Price, 
	--Price_change_slot,
    Round(Avg(Wind_Gen), 0) AS Avg_Wind_Gen,
    ROUND(AVG(Solar_Gen), 0) AS Avg_Solar_Gen,                   
    ROUND(AVG(National_Demand), 0) AS Avg_National_Demand,
	ROUND(AVG(National_Demand - Total_Renewable_Generation), 0) AS Demand_supply_gap
FROM t3
WHERE Settlement_Period IN (28, 29, 30, 31, 32, 33)
GROUP BY Settlement_Period ---, Price_change_slot
ORDER BY Settlement_Period
-- The above table shows drop in avg solar generation, from the settlement period 31 (3:30 pm), 
-- which is the cause of sudden spike in price and then demand_supply gap also increases starts from there. 
-- It shows, nation switches to perhaps fossils, gas or imports or any expensive source which causes this.

With t1 AS 
(
SELECT *, 
    CASE 
        WHEN Avg_Price < 0 THEN '< £0'
        WHEN Avg_Price BETWEEN 0 AND 5 THEN '£0 to £5'
        WHEN Avg_Price > 5 AND Avg_Price <= 10 THEN '(> £5 and <= £10)'
        WHEN Avg_Price > 10 AND Avg_Price <= 15 THEN '(> £10 and <= £15)'
        WHEN Avg_Price > 15 AND Avg_Price <= 20 THEN '(> £15 and <= £20)'
        WHEN Avg_Price > 20 AND Avg_Price <= 25 THEN '(> £20 and <= £25)'
        WHEN Avg_Price > 25 AND Avg_Price <= 30 THEN '(> £25 and <= £30)'
        WHEN Avg_Price > 30 AND Avg_Price <= 35 THEN '(> £30 and <= £35)'
        WHEN Avg_Price > 35 AND Avg_Price <= 42 THEN '(> £35 and <= £42)'
        ELSE '> £42'
    END AS Price_Band
 ,(Wind_Gen + Solar_Gen + Scottish_Transfer) AS Total_Renewable_Generation
FROM vw_Analysis_Price_Demand
) 
SELECT DISTINCT
  Settlement_Period,
  Time_Block,
  Price_Band 
  , count(*) OVER (PARTITION BY Time_Block , Price_Band) AS Feq_time_block
FROM t1
WHERE price_band IN ('< £0')--,'£0 to £5',  '(> £5 and <= £10)')
ORDER BY Time_Block , Price_Band