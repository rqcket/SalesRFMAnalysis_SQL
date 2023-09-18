-- Inspecting Data

Select * 
From [dbo].[sales_data_sample]

---------------------------------------------------------------------------------
 -- Checking unique values and deciding what to plot

Select Distinct PRODUCTLINE FROM [dbo].[sales_data_sample]
Select Distinct COUNTRY FROM [dbo].[sales_data_sample]
Select Distinct DEALSIZE FROM [dbo].[sales_data_sample]
Select Distinct YEAR_ID FROM [dbo].[sales_data_sample]
Select Distinct TERRITORY FROM [dbo].[sales_data_sample]
Select Distinct STATUS FROM [dbo].[sales_data_sample]


---------------------------------------------------------------------------------
-- Standardizing Date Format 

 ALTER TABLE  [dbo].[sales_data_sample]
 Add OrderDateConverted Date;

 UPDATE [dbo].[sales_data_sample]
 SET OrderDateConverted = CONVERT(DATE, OrderDate)

ALTER TABLE [dbo].[sales_data_sample]
DROP COLUMN OrderDate


---------------------------------------------------------------------------------
--Analysis 


Select * 
From [dbo].[sales_data_sample]
 
-- Sum of sales for each productline and which product generates the most sales : 

Select PRODUCTLINE,SUM(SALES) AS ALL_Sales
FROM  [dbo].[sales_data_sample]
GROUP BY PRODUCTLINE
ORDER BY 2 desc

-- Sales per year

Select YEAR_ID,SUM(SALES) AS ALL_Sales
FROM  [dbo].[sales_data_sample]
GROUP BY YEAR_ID
ORDER BY 1 

-- Checking Last Sale Made entry for each year
SELECT YEAR_ID,MAX(OrderDateConverted) as LastSaleDate
FROM [dbo].[sales_data_sample]
GROUP BY YEAR_ID
ORDER BY 2

-- checking month wise

Select MONTH_ID,SUM(SALES) as Revenue,COUNT(ORDERNUMBER) as Frequency
FROM [dbo].[sales_data_sample]
GROUP BY MONTH_ID
ORDER BY 1,3

-- Max sales are in month of november of year 2003 and 2004

Select MONTH_ID,PRODUCTLINE,SUM(SALES) as Revenue,COUNT(ORDERNUMBER) as Frequency
FROM [dbo].[sales_data_sample]
WHERE YEAR_ID=2003 AND MONTH_ID=11
GROUP BY MONTH_ID,PRODUCTLINE
ORDER BY 3 DESC

---------------------------------------------------------------------------------
-- To determine who the best customer is using RFM (Recency-Frequency-Monetary) 
/*  Window functions applies aggregate and ranking functions over a particular window (set of rows). 
    OVER clause is used with window functions to define that window. OVER clause does two things : 
    Partitions rows into form set of rows. (PARTITION BY clause is used) 
    Orders rows within those partitions into a particular order. (ORDER BY clause is used) */

	/*The NTILE function is an OLAP ranking function that classifies 
	the rows in each partition into N ranked categories, called tiles,
	where each category includes an approximately equal number of rows. */

-- (CTE) is a temporary named result set that you can reference within a SELECT, INSERT, UPDATE, or DELETE statement.
-- Using CTE
DROP TABLE IF EXISTS #rfm

;WITH RFM AS 
(
SELECT CUSTOMERNAME, sum(Sales) MonetaryValue,
avg(Sales) AvgMonetaryValue,
count(ORDERNUMBER) Frequency,
max(ORDERDATECONVERTED) last_order_date,
DATEDIFF(DD,max(ORDERDATECONVERTED),(SELECT MAX(ORDERDATECONVERTED) FROM [dbo].[sales_data_sample])) Recency
FROM [dbo].[sales_data_sample]
group by CUSTOMERNAME 
--ORDER BY 2 desc
),
rfm_calc as 
(
SELECT r.*,NTILE(4) OVER (ORDER BY Recency desc ) rfm_recency	,
           NTILE(4) OVER (ORDER BY Frequency) rfm_frequency	,
		   NTILE(4) OVER (ORDER BY MonetaryValue) rfm_monetary
from RFM r
)

SELECT c.*, rfm_recency+ rfm_frequency+rfm_monetary as rfm_cell,
cast(rfm_recency as varchar)+ cast(rfm_frequency as varchar)+cast(rfm_monetary as varchar) as rfm_cell_string
into #rfm
from rfm_calc c

-- Created a table.


select CUSTOMERNAME , rfm_recency, rfm_frequency, rfm_monetary,
	case 
		when rfm_cell_string in (111, 112 , 121, 122, 123, 132, 211, 212, 114, 141, 221) then 'lost_customers'  --lost customers
		when rfm_cell_string in (133, 134, 143, 244, 334, 343, 344, 144, 234) then 'slipping away, cannot lose' -- (Big spenders who haven’t purchased lately)
		when rfm_cell_string in (311, 411, 331, 412, 421) then 'new customers'
		when rfm_cell_string in (222, 223, 233, 322, 232) then 'losing them' --(Customers who don't buy much often and if they do then they don't spend much)
		when rfm_cell_string in (323, 333,321, 422, 332, 432, 423) then 'active' --(Customers who buy often & recently, but at low price points)
		when rfm_cell_string in (433, 434, 443, 444) then 'loyal'
	end rfm_segment
from #rfm

-- Finding which products are often sold together
select distinct OrderNumber, stuff(

	(select ',' + PRODUCTCODE
	from [dbo].[sales_data_sample] p
	where ORDERNUMBER in 
		(

			select ORDERNUMBER
			from (
				select ORDERNUMBER, count(*) rn
				FROM [sales_data_sample]
				where STATUS = 'Shipped'
				group by ORDERNUMBER
			)m
			where rn = 3
		)
		and p.ORDERNUMBER = s.ORDERNUMBER
		for xml path (''))

		, 1, 1, '') ProductCodes

from [dbo].[sales_data_sample] s
order by 2 desc

--Which country has had the highest number of sales 

Select distinct country From [dbo].[sales_data_sample]


Select country, sum (sales) Revenue
From [dbo].[sales_data_sample]
--Where country = 'Canada'
Group by country
Order by 2 desc