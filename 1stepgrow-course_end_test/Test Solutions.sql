USE testing_db

--Top 3 employees in each department where the employee salary is the closest to the average salary of the department

WITH 
avg_salary_department AS
(
	SELECT employee_dept, AVG(salary) AS avg_salary
	FROM employees
	GROUP BY employee_dept
),
shortlisted_emps AS
(
	SELECT  employee_name
		   ,employees.employee_dept
		   ,salary
		   ,avg_salary
		   ,ABS(salary - avg_salary) AS difference
		   ,DENSE_RANK() OVER(PARTITION BY employees.employee_dept ORDER BY ABS(salary - avg_salary)) AS number
	FROM avg_salary_department 
	JOIN employees
	ON employees.employee_dept = avg_salary_department.employee_dept
)
SELECT employee_name
	   ,employee_dept
	   ,salary
	   ,avg_salary
FROM shortlisted_emps
WHERE number IN (1,2,3)
ORDER BY employee_dept, salary DESC



---Rank the  department by the highest salary by department

WITH dept_number AS
(
	SELECT employee_name
		   ,employee_dept
		   ,salary
		   ,DENSE_RANK() OVER(PARTITION BY employees.employee_dept ORDER BY salary DESC) AS number
	FROM employees
)
SELECT employee_dept
	   ,salary
	   ,ROW_NUMBER() OVER (ORDER BY salary DESC) AS dept_rank
FROM dept_number
WHERE number = 1



-- Find the employee who earns the 10th highest salary?

WITH ranked_emps AS
(
	SELECT employee_name
		   , salary
		   , RANK() Over(ORDER BY salary DESC) AS number
	FROM employees
)
SELECT * FROM ranked_emps 
WHERE number = 10



--Find all the employees from all other department who earn more salary than the employee who earns the highest salary in SD-Infra department

SELECT employee_name
	  , employee_dept
	  , salary
FROM employees
WHERE salary > (SELECT TOP 1 salary
FROM employees
WHERE employee_dept = 'SD-Infra'
ORDER BY salary DESC)



-- Write a stored procedure that takes a number as an input and returns the employees from each department who has the nth rank based on their salary within his/her department.

GO

CREATE PROCEDURE employees_department_salaried_rank @emp_number INT
AS
SELECT * FROM 
(
	SELECT employee_name
		   , employee_dept
		   , salary
		   , RANK() OVER (PARTITION BY employee_dept ORDER BY salary DESC) AS employee_rank
	FROM employees
) 
AS emps_ranked
where employee_rank = @emp_number
GO
EXEC employees_department_salaried_rank @emp_number = 5



-- Find the state which has the highest total sales after discount

SELECT TOP 1 SUBSTRING(sales_location , CHARINDEX( ',' , sales_location)+1 , LEN(sales_location)) AS state
		,SUM((quantity * item_price) * (CAST(disc_perc AS FLOAT)/100)) AS discounted_sales
FROM orders
JOIN discounts
ON YEAR(purchase_date) = disc_year
AND MONTH(purchase_date) = disc_month
JOIN salesman
ON salesman.sales_id = orders.salesman_id
GROUP BY SUBSTRING(sales_location , CHARINDEX( ',' , sales_location)+1 , LEN(sales_location))
ORDER BY discounted_sales DESC



-- Find the state which has the maximum number of customers

SELECT TOP 1 COUNT(*) AS customers_count
	   , SUBSTRING(customer_address, CHARINDEX(',', customer_address)+1 , len(customer_address)) AS states
FROM customers
GROUP BY SUBSTRING(customer_address, CHARINDEX(',', customer_address)+1 , len(customer_address))
ORDER BY customers_count DESC




-- Find the top 10th customer in terms of total revenue after discount.

WITH table1 AS
(
	SELECT customers.customer_name
		   , sum((item_price * (1-(CAST(disc_perc AS FLOAT)/100))) * quantity ) AS revenue
	FROM orders 
	JOIN discounts AS d
	ON d.disc_year = YEAR(purchase_date)
	AND d.disc_month = MONTH(purchase_date)
	JOIN customers
	ON orders.customer_id = customers.customer_id
	GROUP BY customers.customer_name
) ,
table2 AS
(
	SELECT * 
		   , RANK() OVER(ORDER BY revenue DESC) as customer_rank
	FROM table1
)
SELECT customer_name
		, revenue
FROM table2 
WHERE customer_rank = 10





-- Find the salesman whose total sales after discount is nearest to the average sales(total revenue) of all the salesman.

WITH discounted_sales_salesman AS
(
SELECT salesman_id
	   , SUM((quantity * item_price) * ((100 - CAST(disc_perc AS float))/100)) AS discounted_sales
FROM discounts
JOIN orders
ON discounts.disc_year = YEAR(purchase_date)
AND discounts.disc_month = MONTH(purchase_date)
GROUP BY salesman_id
)
SELECT salesman.sales_name
	   , discounted_sales_salesman.discounted_sales
FROM discounted_sales_salesman
JOIN salesman
ON salesman.sales_id = discounted_sales_salesman.salesman_id
ORDER BY sales_name
	  


-- Find the customer who has the highest purchase based on the state?

WITH customer_purchase AS
(
	SELECT  customer_name
			,SUBSTRING(customer_address , CHARINDEX( ',' , customer_address) +1 , len(customer_address)) AS state
			,SUM(quantity*item_price) AS purchase
	FROM customers
	JOIN orders
	ON customers.customer_id = orders.customer_id
	GROUP BY customer_name, SUBSTRING(customer_address , CHARINDEX( ',' , customer_address) +1 , len(customer_address))
),
state_rank AS
(
	SELECT customer_name
		   , state
		   , purchase
		   ,RANK() OVER(PARTITION BY state ORDER BY purchase DESC) AS state_purch_rank
	FROM customer_purchase
)
SELECT customer_name
		,state
		,purchase
FROM state_rank 
WHERE state_purch_rank = 1
ORDER BY purchase DESC





-- Find the month-year where the maximum total discount was given?

SELECT disc_year 
		, DateName( month , DateAdd( month , disc_month , -1 ) ) AS months
		, SUM((quantity*item_price) * (CAST(disc_perc AS float)/100)) AS discount_given
FROM discounts
JOIN orders
ON YEAR(purchase_date) = disc_year
AND MONTH(purchase_date) = disc_month
GROUP BY disc_year , disc_month
ORDER BY discount_given DESC




-- -- Find the state (customer's state) Ranked number 4 in terms of quantity of products purchased
SELECT * 
FROM (
		SELECT SUBSTRING(customer_address , CHARINDEX(',' , customer_address) + 1, LEN(customer_address)) AS state
			   , sum(quantity) AS quantity_purchased
			   , RANK() OVER (ORDER BY sum(quantity) DESC) AS state_rank
		FROM customers
		JOIN orders
		ON customers.customer_id  = orders.customer_id
		GROUP BY SUBSTRING(customer_address , CHARINDEX(',' , customer_address) + 1, LEN(customer_address))
	)
AS table1
WHERE state_rank = 4



-- Find the name of the customer who got the 5th highest rank in terms of total discount in all his/her purchase

WITH table1 AS
(
	SELECT customers.customer_name
		   , sum((item_price * (CAST(disc_perc AS FLOAT)/100)) * quantity ) AS total_discount
	FROM orders 
	JOIN discounts AS d
	ON d.disc_year = YEAR(purchase_date)
	AND d.disc_month = MONTH(purchase_date)
	JOIN customers
	ON orders.customer_id = customers.customer_id
	GROUP BY customers.customer_name
) ,
table2 AS
(
	SELECT * 
		   , RANK() OVER(ORDER BY total_discount DESC) as customer_rank
	FROM table1
)
SELECT customer_name
		, total_discount
FROM table2 
WHERE customer_rank = 5




-- Rank the bottom 10 customers in terms of the total purchase after discount in order of age (ASCENDING)

SELECT * from customers
SELECT * from orders order by customer_id

SELECT subquery.customer_name
		, subquery.discounted_sales	
		, subquery.age 
FROM (
		SELECT customers.customer_name
				, SUM((quantity * item_price) * (CAST(disc_perc AS FLOAT)/100)) AS discounted_sales
				, (YEAR(GETDATE()) - YEAR(customer_dob)) as age
				, RANK() OVER(ORDER BY (SUM((quantity * item_price) * (CAST(disc_perc AS FLOAT)/100)) ))AS ranked_sales
		FROM orders
		JOIN discounts
		ON YEAR(purchase_date) = disc_year
		AND MONTH(purchase_date) = disc_month
		JOIN customers
		ON customers.customer_id = orders.customer_id
		GROUP BY customer_name , (YEAR(GETDATE()) - YEAR(customer_dob)) 
		) AS subquery
WHERE ranked_sales <=10
ORDER BY age



-- find the bottom 10 customers in terms of the total value of purchase after discount.

WITH table1 AS
(
	SELECT customers.customer_name
		   , sum((item_price * (1-(CAST(disc_perc AS FLOAT)/100))) * quantity ) AS revenue
	FROM orders 
	JOIN discounts AS d
	ON d.disc_year = YEAR(purchase_date)
	AND d.disc_month = MONTH(purchase_date)
	JOIN customers
	ON orders.customer_id = customers.customer_id
	GROUP BY customers.customer_name
) ,
table2 AS
(
	SELECT * 
		   , RANK() OVER(ORDER BY revenue ) as customer_rank
	FROM table1
)
SELECT customer_name
		, revenue
FROM table2 
order by revenue


--- In orders table, sales is made in only 2015 and 2023. And discount is provided from 2015 to 2022. 
SELECT * FROM discounts
SELECT * FROM orders order by purchase_date


