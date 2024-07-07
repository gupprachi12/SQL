CREATE DATABASE music
USE music


---Checking the datasets
SELECT * FROM artist
SELECT * FROM album
SELECT * FROM track
SELECT * FROM genre
SELECT * FROM invoice
SELECT * FROM customer

--- List of songs that are longer than average length of songs


SELECT name
	   ,milliseconds
FROM track
WHERE milliseconds > (SELECT avg(milliseconds) FROM track)
ORDER BY milliseconds DESC


---Which countries have the most invoices


SELECT billing_country
	  ,count(billing_country) AS number_of_bills
FROM invoice
GROUP BY billing_country
ORDER BY number_of_bills DESC


---Values of the top 3 invoices


SELECT TOP 3 billing_country
	  ,count(billing_country) AS number_of_bills
	  ,CEILING(total) AS value_of_invoices
FROM invoice
GROUP BY billing_country , total
ORDER BY total DESC



---Most popular genre of each country on the basis of sales


SELECT inv.billing_country AS country
       , genre.name
	   , SUM(in_l.quantity) AS quantity_sold
	   , SUM(SUM(in_l.quantity)) OVER(PARTITION BY inv.billing_country) AS total_quantity_sold
FROM invoice AS inv
LEFT JOIN invoice_line AS in_l
ON inv.invoice_id = in_l.invoice_id
LEFT JOIN track AS tr
ON in_l.track_id = tr.track_id
LEFT JOIN genre
ON genre.genre_id = tr.genre_id
GROUP BY genre.name , inv.billing_country 
ORDER BY  total_quantity_sold DESC , country 



--- only top 1 popular genre of all the countries



WITH countries_fav_music AS
(

	SELECT inv.billing_country AS country
		, genre.name
		, SUM(in_l.quantity) AS quantity_sold
		, ROW_NUMBER() OVER( PARTITION BY  inv.billing_country ORDER BY SUM(in_l.quantity) DESC) as number
	FROM invoice AS inv
	LEFT JOIN invoice_line AS in_l
	ON inv.invoice_id = in_l.invoice_id
	LEFT JOIN track AS tr
	ON in_l.track_id = tr.track_id
	LEFT JOIN genre
	ON genre.genre_id = tr.genre_id
	GROUP BY genre.name , inv.billing_country 
)
SELECT * FROM countries_fav_music 
WHERE number = 1
ORDER BY quantity_sold DESC


---Optimum cities for promoting the music festival


SELECT billing_city
	  ,ROUND(sum(total), 0) AS invoice_total
FROM invoice
GROUP BY billing_city
HAVING ROUND(sum(total), 0) > 150
ORDER BY invoice_total DESC



---Get the data for artists who have written most the rock music



SELECT TOP 10 art.name
			  ,count(art.artist_id) AS number_of_songs
FROM artist AS art
INNER JOIN album AS al
ON art.artist_id = al.artist_id
INNER JOIN track AS t
ON al.album_id = t.album_id
WHERE t.track_id IN ( SELECT track_id FROM track JOIN genre AS g ON g.genre_id = t.genre_id WHERE g.name = 'rock')
GROUP BY art.name
ORDER BY number_of_songs DESC


---Get the contact details of the customers who listen to Rock music



SELECT DISTINCT c.first_name
				,c.last_name
				,c.city
				,c.phone
				,c.email
FROM customer AS c
INNER JOIN invoice AS i 
ON c.customer_id = i.customer_id
INNER JOIN invoice_line AS il
ON i.invoice_id = il.invoice_id
INNER JOIN track AS t
ON il.track_id = t.track_id
INNER JOIN genre AS g
ON g.genre_id = t.genre_id 
WHERE g.name LIKE 'ro%'
ORDER BY email 



--- Who has spent maximum money


SELECT C.first_name
	   ,C.last_name
	   ,C.city
	   ,CEILING(sum(total)) AS amount_spend
FROM customer as C
JOIN invoice AS I
ON C.customer_id = I.customer_id
GROUP BY  C.customer_id
         ,C.first_name
	     ,C.last_name
	     ,C.city
HAVING CEILING(sum(total)) > 100
ORDER BY amount_spend DESC



---Money spend by each customer on best 3 artist



WITH best_artist AS 
(
	SELECT TOP 3 a.name AS artist_name
		 , a.artist_id
		 , SUM(in_l.unit_price * in_l.Quantity) AS total_sales
	FROM invoice_line AS in_l
	JOIN track AS trk
	ON in_l.track_id = trk.track_id
	JOIN album AS alb
	ON alb.album_id = trk.album_id
	JOIN artist AS a
	ON a.artist_id = alb.artist_id
	GROUP BY a.name , a.artist_id
	ORDER BY total_sales DESC
) 

SELECT c.first_name AS customer_firstname
	  ,c.last_name AS customer_lastname
	  ,art.artist_name AS artist_name
	  ,SUM(il.unit_price*il.quantity) AS amount_spend
	  ,SUM(SUM(il.unit_price*il.quantity)) OVER(PARTITION BY artist_name) AS total_amount_spend
FROM customer AS c
JOIN invoice AS i
ON c.customer_id = i.customer_id
JOIN invoice_line AS il
ON il.invoice_id = i.invoice_id
JOIN track AS t
ON t.track_id = il.track_id
JOIN album AS al
ON t.album_id = al.album_id
JOIN best_artist AS art
ON art.artist_id = al.artist_id
GROUP BY c.first_name
	  ,c.last_name
	  ,artist_name
ORDER BY total_amount_spend DESC


---customer who spends most of music in each country



WITH prime_customers AS
(
	SELECT cus.first_name
		  ,cus.last_name
		  ,inv.billing_country
		  ,ROUND(SUM(inv.total), 2, 1) AS amount_spend
		  ,ROW_NUMBER() OVER(PARTITION BY inv.billing_country ORDER BY SUM(inv.total) DESC) AS number
	FROM invoice AS inv
	JOIN customer AS cus
	ON cus.customer_id = inv.customer_id
	GROUP BY cus.first_name , cus.last_name , inv.billing_country
)
SELECT * FROM prime_customers
WHERE number = 1
AND amount_spend > = 100
ORDER BY amount_spend DESC
