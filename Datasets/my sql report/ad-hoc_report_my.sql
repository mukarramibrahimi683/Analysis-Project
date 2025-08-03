-- SQL Based Business Requests ad-hoc Report---------------
--Data base Overview--
Select * From fact_trips
SELECT * from dim_date
Limit 10; 


-- Business Requirement 1: City-Level fare and trip Summary Report---------
SELECT 
city_name,
COUNT(trip_id) AS total_trips,
ROUND(SUM(fare_amount)/SUM(distance_travelled_km)::numeric,2) AS avg_fare_per_km,
ROUND(AVG(fare_amount)::numeric,2) AS avg_fare_per_trip,
ROUND(COUNT(trip_id)/(SELECT COUNT(trip_id) FROM fact_trips)::numeric*100,2) AS contribution_to_total_trips
FROM fact_trips AS FT
JOIN dim_city   AS DC
ON DC.city_id=FT.city_id
GROUP BY city_name


--Business Requirement 2: Monthly City-Level Trips Target Performance Report----
-- SELECT * FROM dim_date
WITH  acutal_trips_table AS(
SELECT 
COUNT(trip_id) AS actual_trips,
month_name,
start_of_month,
city_id
FROM fact_trips AS FT
JOIN dim_date   AS DD
ON FT.date=DD.Date
GROUP BY FT.city_id,DD.month_name,start_of_month
)

SELECT 
DC.city_name,
ACT.month_name,
ACT.actual_trips,
MTT.total_target_trips,
(CASE WHEN ACT.actual_trips>MTT.total_target_trips then 'Above Target' else 'Below Target' end) AS performance_status,
ROUND((ACT.actual_trips-MTT.total_target_trips)::numeric/(MTT.total_target_trips)*100,2) AS pct_difference
FROM monthly_target_trips AS MTT
JOIN dim_city AS DC
ON DC.city_id=MTT.city_id
JOIN acutal_trips_table AS ACT
ON MTT.month=ACT.start_of_month AND ACT.city_id=MTT.city_id



-- 3) City-Level Repeat Passenger Trip Frequency Report
/* Generate a report that shows the percentage distribution of repeat passengers by the number of trips they have taken in each city. Calculate the percentage of repeat passengers who took 2 trips, 3 trips, and so on, up to 10 trips.
Each column should represent a trip count category, displaying the percentage of repeat passengers who fall into that category out of the total repeat passengers for that city.
This report will help identify cities with high repeat trip frequency, which can indicate strong customer loyalty or frequent usage patterns.

Fields: city_name, 2-Trips, 3-Trips, 4-Trips, 5-Trips, 6-Trips, 7-Trips, 8-Trips, 9-Trips, 10-Trips */
WITH city_wise_total_repeat_passenger AS (
    SELECT
        city_id, 
        SUM(repeat_passenger_count) AS repeat_passenger
    FROM dim_repeat_trip_distribution
    GROUP BY city_id
),

city_trip_frequency AS (
    SELECT 
        rtd.city_id,
        rtd.trip_count,
        ROUND(
            (SUM(rtd.repeat_passenger_count)::numeric / crp.repeat_passenger) * 100, 2
        ) AS repeat_passenger_pct
    FROM dim_repeat_trip_distribution rtd
    JOIN city_wise_total_repeat_passenger crp
        ON rtd.city_id = crp.city_id
    GROUP BY rtd.city_id, rtd.trip_count, crp.repeat_passenger
)

--Here, MAX() just picks the non-null value from the rows matching the CASE condition common technique to pivot rows into columns in SQL.--
SELECT 
    c.city_name,
    MAX(CASE WHEN trip_count = '2-Trips'  THEN repeat_passenger_pct END) AS "2_Trips",
    MAX(CASE WHEN trip_count = '3-Trips'  THEN repeat_passenger_pct END) AS "3_Trips",
    MAX(CASE WHEN trip_count = '4-Trips'  THEN repeat_passenger_pct END) AS "4_Trips",
    MAX(CASE WHEN trip_count = '5-Trips'  THEN repeat_passenger_pct END) AS "5_Trips",
    MAX(CASE WHEN trip_count = '6-Trips'  THEN repeat_passenger_pct END) AS "6_Trips",
    MAX(CASE WHEN trip_count = '7-Trips'  THEN repeat_passenger_pct END) AS "7_Trips",
    MAX(CASE WHEN trip_count = '8-Trips'  THEN repeat_passenger_pct END) AS "8_Trips",
    MAX(CASE WHEN trip_count = '9-Trips'  THEN repeat_passenger_pct END) AS "9_Trips",
    MAX(CASE WHEN trip_count = '10-Trips' THEN repeat_passenger_pct END) AS "10_Trips"
FROM city_trip_frequency ctf
JOIN dim_city c
    ON ctf.city_id = c.city_id
GROUP BY c.city_name;


--Q4. Generate a report that calculates the total new passengers for each city and ranks them based on this value. 
--Identify the top 3 cities with the highest number of new passengers as well as the bottom 3 cities with the lowest number 
--of new passengers, categorizing them as "Top 3" or "Bottom 3" accordingly.


WITH  citywise_new_passengers   AS (
SELECT 
city_id,
SUM(new_passengers) AS total_new_passengers,
RANK() OVER (ORDER BY SUM(new_passengers) DESC) AS rank_position
FROM fact_passenger_summary
GROUP  BY city_id)

SELECT 
city_name,
total_new_passengers,
(CASE WHEN rank_position=1 or  rank_position=2 or rank_position=3 THEN 'Top 3'  
 WHEN rank_position IN (8,9,10) THEN 'Bottom 3'END) AS city_category -- use In operatoer it is shorthand of wiritng multiple or statements
 FROM citywise_new_passengers AS CNP
 JOIN dim_city
 ON dim_city.city_id=CNP.city_id
 WHERE rank_position<=3 or rank_position>=8
 ORDER BY total_new_passengers DESC
 


--Q5. Generate a report that identifies the month with the highest revenue for each city. For each city, display the month name, the revenue amount for that month,
--and the percentage contribution of that month's revenue to the city's total revenue.


WITH city_monthwise_reveneue AS (
SELECT 
city_id,
month_name,
SUM(fare_amount) AS revenue,
RANK() OVER (PARTITION BY city_id ORDER BY SUM(fare_amount) DESC) AS month_rank
FROM fact_trips
JOIN dim_date
ON fact_trips.date=dim_date.date
GROUP BY city_id,month_name
)

SELECT 
city_name,
MAX(CASE WHEN month_rank=1 THEN month_name ELSE NULL END) AS highest_revenue_month,
ROUND(MAX(revenue)/1000000::numeric,2) AS revenue_in_mil,
ROUND(MAX(revenue)/SUM(revenue)*100::numeric,2) AS pct_contribution
FROM city_monthwise_reveneue AS CMR
JOIN dim_city
ON dim_city.city_id=CMR.city_id
GROUP BY city_name


--Q6. Generate a report that calculates two metrics:

--→ Monthly Repeat Passenger Rate: Calculate the repeat passenger rate for each city and month by comparing the number of repeat passengers to the total passengers.

--→ City-wise Repeat Passenger Rate: Calculate the overall repeat passenger rate for each city, considering all passengers across months.


with monthly_rpr as (
SELECT 
	city_id,
    month_name,
    total_passengers,
    repeat_passengers,
    round((repeat_passengers/total_passengers::numeric)*100,2) as monthly_rpr
FROM fact_passenger_summary fps
join dim_date d
on fps.month = d.start_of_month
group by city_id, month_name, total_passengers,repeat_passengers
),

overall_city_wise_rpr as (
select
	city_id,
    round((sum(repeat_passengers)/sum(total_passengers::numeric))*100,2) as overall_rpr
from fact_passenger_summary
group by city_id
)

select
	city_name,
    month_name,
    total_passengers,
    repeat_passengers,
    monthly_rpr,
    overall_rpr
from monthly_rpr mr
join overall_city_wise_rpr ocr 
on mr.city_id = ocr.city_id
join dim_city c
on mr.city_id = c.city_id
Order by city_name;


