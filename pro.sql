--****************************************************************************************************************************************-

--                                       --  CHARLIE BOTELLO --
--Views
--Two versions of two queries are provided. Refer to: QueriesProvided.sql
--1.     Current_Shareholder_Shares – Two queries are provided in QueriesProvided.sql.  Both of these queries list shareholder id, 
--shareholder type, stock id, and the total shares currently held by the shareholder.  Create a view called CURRENT_SHAREHOLDER_SHARES using the 
--****************************************************************************************************************************************--

CREATE OR REPLACE VIEW Current_shareholder_Shares
AS
SELECT 
   nvl(buy.buyer_id, sell.seller_id) AS shareholder_id,
   sh.type,
   nvl(buy.stock_id, sell.stock_id) AS  stock_id, 
   CASE nvl(buy.buyer_id, sell.seller_id)
      WHEN c.company_id THEN NULL
      ELSE nvl(buy.shares,0) - nvl(sell.shares,0)
   END AS shares
FROM (SELECT 
        t_sell.seller_id,
        t_sell.stock_id,
      sum(t_sell.shares) AS shares
      FROM trade t_sell
      WHERE t_sell.seller_id IS NOT NULL
      GROUP BY t_sell.seller_id, t_sell.stock_id) sell
  FULL OUTER JOIN
     (SELECT 
        t_buy.buyer_id,  
        t_buy.stock_id,
        sum(t_buy.shares) AS shares
      FROM trade t_buy
      WHERE t_buy.buyer_id IS NOT NULL
      GROUP BY t_buy.buyer_id, t_buy.stock_id) buy
   ON sell.seller_id = buy.buyer_id
   AND sell.stock_id = buy.stock_id
  JOIN shareholder sh
    ON sh.shareholder_id = nvl(buy.buyer_id, sell.seller_id)
  JOIN company c
    ON c.stock_id = nvl(buy.stock_id, sell.stock_id)
WHERE nvl(buy.shares,0) - nvl(sell.shares,0) != 0
ORDER BY 1,3
;


--=======my version ==-----

--======myversi
-- The best tool to use autotrace, it gives us stastistics of an executed query.
-- The information that this provides that is the most useful is consistent gets. This 
-- tells us how many times oracle must read the blocks in order to process the information 

-- From the first set of querries (Current_shareholder_Shares), has a lower consistent gets.  

-- Both of the tables reduce the use of order by stock_id, make it easier for oracle to process informationl,
-- Use of joins such as outer join prevent duplicate tables with the same information to be streamed through.







--****************************************************************************************************************************************--
--more efficient query and include the view in your script. Please place a comment explaining why you chose the query.
--2.     Current_Stock_Stats – These queries list each stock id, the number of shares currently authorized, and the total number of shares currently outstanding. 
--Create a view called CURRENT_STOCK_STATS using the more efficient query and include it in your script.  Please place a comment explaining why you chose the query.
--****************************************************************************************************************************************--

CREATE OR REPLACE VIEW CURRENT_STOCK_STATS
AS
SELECT
  co.stock_id,
  si.authorized current_authorized,
  SUM(DECODE(t.seller_id,co.company_id,t.shares)) 
    -NVL(SUM(CASE WHEN t.buyer_id = co.company_id 
             THEN t.shares END),0) AS total_outstanding
FROM company co
  INNER JOIN shares_authorized si
     ON si.stock_id = co.stock_id
    AND si.time_end IS NULL
  LEFT OUTER JOIN trade t
      ON t.stock_id = co.stock_id
GROUP BY co.stock_id, si.authorized
ORDER BY stock_id
;



--============================================useful views=======================================================--
Create OR replace view tr_view
AS 
SELECT 
  tr.stock_ex_id as stock_ex_id,
  tr.stock_id as stock_id,
  MAX(tr.stock_ex_id) as top
FROM trade tr
WHERE tr.stock_ex_id IS NOT NULL
GROUP BY tr.stock_ex_id, tr.stock_id
;




CREATE or replace view company_view AS(
select 
  tr.trade_id as trade_id,
  tr.stock_ex_id as stock_ex_id,
  com.name as name,
  com.stock_id as stock_id,
  tr.shares as shares,
  tr.price_total as total
from company com 
  LEFT JOIN trade tr 
    ON com.stock_id = tr.stock_id
WHERE com.stock_id IS NOT NULL 
AND tr.stock_ex_id IS NOT NULL
GROUP BY   tr.trade_id, 
  tr.stock_ex_id,
  com.name,
  com.stock_id,
  tr.shares,
  tr.price_total)
;



--================================================================================================================--




--****************************************************************************************************************************************--

--Queries
--3.  Write a query which lists the name of every company that has authorized stock,
--the number of shares currently authorized, the total shares currently outstanding, and % of authorized shares that are outstanding.
--Shares outstanding is the number of shares owned by external share holders.  
--Shares_Authorized = Shares_Outstanding + Shares_UnIssued

--****************************************************************************************************************************************--


SELECT 
com.name,
curr.stock_id,
curr.total_outstanding,
ROUND(curr.total_outstanding / curr.current_authorized * 100, 2)  
FROM current_stock_stats curr
 LEFT JOIN company com 
  ON curr.stock_id = com.stock_id
   LEFT JOIN trade tr 
    ON tr.stock_id = com.stock_id
     GROUP BY com.name, curr.stock_id, curr.current_authorized, curr.total_outstanding
;

--============================================old one=======================================================--

-- SELECT 
--   com.name,
--   sa.authorized,
--   SUM(DECODE(tr.seller_id,com.company_id,tr.shares)) 
--    -NVL(SUM(CASE WHEN tr.buyer_id = com.company_id 
--             THEN tr.shares END),0) AS outstanding
-- FROM trade tr
--   JOIN company com
--     ON tr.stock_id = com.stock_id
--       JOIN shares_authorized sa
--         ON com.stock_id = sa.stock_id
-- GROUP BY com.name, sa.authorized
-- ;
--==========================================================================================================--

--****************************************************************************************************************************************--
--4.     For every direct holder: list the name of the holder, the names of the companies invested in by this direct holder,
--number of shares currently held, % this holder has of the shares outstanding, and % this holder has of the total authorized shares.  
--Sort the output by direct holder last name, first name, and company name and display the percentages to two decimal places.

--****************************************************************************************************************************************--




SELECT 
dh.last_name,
dh.first_name,
com.name,
css.shares,
round(cur.total_outstanding - cur.current_authorized * 100, 2),
100 - round((cur.current_authorized - css.shares) / cur.current_authorized * 100, 2)
FROM DIRECT_HOLDER dh 
  LEFT JOIN CURRENT_SHAREHOLDER_SHARES css
    ON css.shareholder_id = dh.direct_holder_id
      LEFT JOIN company com 
        ON com.stock_id = css.stock_id
          LEFT JOIN CURRENT_STOCK_STATS cur
            ON cur.stock_id = css.stock_id
WHERE com.stock_id IS NOT NULL
ORDER BY dh.last_name, dh.first_name, com.name
;



--============================================old one=======================================================--
-- SELECT 
--   com.name,
--   sa.authorized AS "SHARES AUTHORIZED",
--   SUM(DECODE(tr.seller_id, sh.shareholder_id, tr.shares)) 
--    -NVL(SUM(CASE WHEN tr.buyer_id = com.company_id  
--             THEN tr.shares END),2) AS outstanding,
--   ROUND((SUM(DECODE(tr.seller_id, com.company_id, tr.shares)) 
--    -NVL(SUM(CASE WHEN tr.buyer_id = com.company_id  
--             THEN tr.shares END),2)) / sa.authorized, 2 )
-- FROM trade tr
--   JOIN company com
--     ON tr.stock_id = com.stock_id
--       JOIN shares_authorized sa
--         ON com.stock_id = sa.stock_id
--           JOIN shareholder sh
--             ON tr.seller_id = sh.SHAREHOLDER_id
-- GROUP BY com.name,sa.authorized
-- ORDER by com.name
-- ;
--==========================================================================================================--


--****************************************************************************************************************************************--
--5.     For every institutional holder (companies who hold stock): list the name of the holder, the names of the companies invested in by this holder,
--shares currently held, % this holder has of the total shares outstanding, and % this holder has of that total authorized shares. 
--For this report, include only the external holders (not treasury shares). Sort the output by holder name, and company owned name and display the percentages to two decimal places. subquery

--- not working 
--****************************************************************************************************************************************--




WITH needcompany AS (
SELECT 
  com.company_id as com1,
  com.name com2,
  com.stock_id com3,
  tr.buyer_id com4,
  nvl((SELECT 
        comalt.stock_id  
      FROM company comalt
      WHERE comalt.stock_id = tr.buyer_id), 'DHOLDER') AS invested,
      tr.shares com5,
  ROUND(cur_stats.total_outstanding / cur_stats.current_authorized * 100, 2) as per,
  100 - ROUND((cur_stats.current_authorized - tr.shares) / cur_stats.current_authorized * 100, 2) as perdh
FROM CURRENT_SHAREHOLDER_SHARES cshares 
  LEFT JOIN COMPANY com 
    ON com.stock_id = cshares.shareholder_id
      LEFT JOIN TRADE tr 
        ON tr.stock_id = com.stock_id
          LEFT JOIN CURRENT_STOCK_STATS cur_stats 
            ON cur_stats.stock_id = cshares.shareholder_id
WHERE cshares.type = 'Company' 
  AND com.company_id IS NOT NULL
    AND tr.buyer_id IS NOT NULL 
GROUP BY com.company_id, com.name, com.stock_id, tr.buyer_id
)
select 
com1 as  com.company_id,
com2 as  com.name,
com3 as  com.stock_id,
com4 as  tr.buyer_id
invested,
com5 tr.shares,
per,
perdh
FROM needcompany
WHERE invested <> 'DHOLDER'
order by com.name
;



--============================================old one=======================================================--


-- SELECT 
--  com.name,
--  dh.last_name,
--  dh.first_name,
--  tr.shares,
--  round((tr.shares / sa.authorized) * 100) 
-- FROM company com 
--  JOIN trade tr
--   ON com.stock_id = tr.stock_id
--    JOIN direct_holder dh
--     ON dh.direct_holder_id = tr.buyer_id
--    JOIN stock_listing sl
--     ON tr.stock_ex_id = sl.stock_ex_id
--      JOIN shares_authorized sa
--       ON sl.stock_id = sa.stock_id
--        JOIN stock_price sp
--         ON sa.stock_id = sp.stock_id
--          JOIN stock_exchange se 
--           ON sp.stock_ex_id = se.stock_ex_id
--         --   JOIN currency cur
--         --     ON se.currency_id = cur.currency_id
--         --      JOIN conversion con
--         --       ON cur.currency_id = con.from_currency_id
-- -- GROUP BY com.name, dh.last_name, dh.first_name, tr.shares
-- ;

--===================================================================================================--


--****************************************************************************************************************************************--
--6. Write a query which displays all trades where more than 50000 shares were traded on the secondary markets.  Please include the trade id, stock symbol, 
--name of the company being traded, stock exchange symbol, number of shares traded, price total (including broker fees) and currency symbol. subquery
--****************************************************************************************************************************************--

SELECT 
 tr.trade_id,
 sl.stock_symbol,
 com.name,
 se.stock_ex_id,
 tr.shares,
 tr.price_total,
 cur.symbol,
 tr.price_total - (tr.shares * com.starting_price) AS "Including Broker fee"
FROM trade tr
  LEFT JOIN stock_exchange se 
    ON se.stock_ex_id = tr.stock_ex_id
     Left JOIN stock_listing sl
      on sl.stock_id = tr.stock_id
      LEFT JOIN company com
        ON com.stock_id = tr.stock_id
          LEFT JOIN currency cur 
            ON cur.currency_id = se.currency_id
WHERE tr.trade_id IS NOT NULL 
  AND tr.shares > 5000
-- GROUP BY  tr.trade_id, sl.stock_symbol, com.name, se.stock_ex_id, tr.shares, tr.price_total, cur.symbol
;




--======================================old one========================================================--




-- SELECT 
--  tr.trade_id,
--  sl.stock_symbol,
--  com.name,
--  tr.price_total,
--  cur.symbol,
--  SUM (tr.price_total - (tr.shares*sp.price)) AS "Including Broker fee"
-- FROM company com 
--  JOIN trade tr
--   ON com.stock_id = com.stock_id
--    JOIN stock_listing sl
--     ON tr.stock_ex_id = sl.stock_ex_id
--      JOIN shares_authorized sa
--       ON sl.stock_id = sa.stock_id
--        JOIN stock_price sp
--         ON sa.stock_id = sp.stock_id
--          JOIN stock_exchange se 
--           ON sp.stock_ex_id = se.stock_ex_id
--            JOIN currency cur
--             ON se.currency_id = cur.currency_id
-- WHERE trunc(tr.transaction_time,'dd') = trunc(sp.time_start,'dd')
-- AND tr.shares > 5000
-- GROUP BY tr.trade_id, sl.stock_symbol, com.name, tr.price_total, cur.symbol
-- ;
--===================================================================================================--

--****************************************************************************************************************************************--
-- 7.     For each stock listed on each stock exchange, display the exchange name, stock symbol 
-- and the date and time when that the stock was last traded. Sort the output by stock exchange name, stock symbol.  
-- If a stock has not been traded show the exchange name, stock symbol and null for the date and time. 

--****************************************************************************************************************************************--




SELECT 
 se.name,
 sl.stock_symbol,
 tr.transaction_time AS "Transaction Date",
 NVL(to_char(tr.transaction_time, 'hh24:mi:ss'), NULL) AS "Transaction Time",
 com.name,
 tr.price_total,
 cur.symbol,
 tr.price_total - (tr.shares*sp.price) AS "Broker's Fee"
FROM company com 
 JOIN trade tr
  ON com.stock_id = com.stock_id
   JOIN stock_listing sl
    ON tr.stock_ex_id = sl.stock_ex_id
     JOIN shares_authorized sa
      ON sl.stock_id = sa.stock_id
       JOIN stock_price sp
        ON sa.stock_id = sp.stock_id
         JOIN stock_exchange se 
          ON sp.stock_ex_id = se.stock_ex_id
           JOIN currency cur
            ON se.currency_id = cur.currency_id
WHERE trunc(tr.transaction_time,'dd') = trunc(sp.time_start,'dd')
ORDER BY se.name, se.symbol
;




--=====old====-----

-- SELECT
--   se.name,
--   sl.stock_symbol,
--   tr.stock_ex_id,
--   nvl(tr.stock_id, NULL),
--   MAX(trunc(tr.transaction_time, 'dd'))
-- FROM stock_exchange se 
--   LEFT JOIN stock_listing sl 
--     ON sl.stock_ex_id. = se.stock_ex_id
--       INNER JOIN trade tr 
--         ON tr.stock_id = sl.stock_id
-- GROUP BY se.name, sl.stock_symbol, tr.stock_ex_id
-- ORDER BY se.name, sl.stock_symbol
-- ;
--=====old====-----

--===================================================================================================--
-- 8.     Display the trade_id, name of the company and number of shares for the single largest trade 
-- made on any secondary market (in terms of the number of shares traded). Unless there are multiple 
-- trades with the same number of shares traded, only one record should be returned.
--===================================================================================================--

--==views listed at the beggining====================================================================-
SELECT 
  (select
    needtr.trade_id
    FROM trade needtr
    WHERE needtr.stock_id = viewing.stock_id
    AND needtr.shares = viewing.top
    AND needtr.stock_ex_id = viewing.stock_ex_id
    AND ROWNUM <= 1) as trade_id, 
    viewing.top,
    (SELECT com.name
     FROM company com
     WHERE com.stock_id = viewing.stock_id),
     viewing.stock_ex_id
FROM tr_view viewing
;


--=============================================old==================================================--


-- SELECT 
--  tr.trade_id,
--  com.name,
--  MAX(tr.shares) AS "Highest T"
-- FROM company com 
--  JOIN trade tr
--   ON com.stock_id = com.stock_id
--    JOIN stock_listing sl
--     ON tr.stock_ex_id = sl.stock_ex_id
--      JOIN shares_authorized sa
--       ON sl.stock_id = sa.stock_id
--        JOIN stock_price sp
--         ON sa.stock_id = sp.stock_id
--          JOIN stock_exchange se 
--           ON sp.stock_ex_id = se.stock_ex_id
--            JOIN currency cur
--             ON se.currency_id = cur.currency_id

-- WHERE trunc(tr.transaction_time,'dd') = trunc(sp.time_start,'dd')
-- GROUP BY tr.trade_id, com.name
-- ;
--===================================================================================================--


--****************************************************************************************************************************************--

-- Data Manipulation
-- Write the necessary INSERT, UPDATE and/or DELETE statements to complete the following data changes. 

-- Add a Direct Holder
-- 9.     Add “Jeff Adams” as a new direct holder.  
--You will have to insert a record into the shareholder table and make a separate statement to insert into the direct_holder table.
--****************************************************************************************************************************************--
select * from shareholder order by shareholder_id desc;


CREATE SEQUENCE seq_shareholder_id 
  INCREMENT BY 1
  START WITH 26
;


INSERT INTO shareholder 
    (shareholder_id, type)
 VALUES(seq_shareholder_id.nextval, 'Direct_Holder');

INSERT INTO direct_holder
   (direct_holder_id,first_name,last_name) 
  VALUES (seq_shareholder_id.currval,'Jeff','Adams');
--****************************************************************************************************************************************--
-- 10.     Add “Makoto Investing” as a new institutional holder that has its head office in Tokyo, Japan.  
--Makoto does not currently have a stock id.  A record must be inserted into the shareholder table and a corresponding record 
--must be inserted into the company table.
--****************************************************************************************************************************************--
select * from shareholder order by shareholder_id desc;
select * from company order by company_id desc;
select * from place;

INSERT INTO shareholder 
  (shareholder_id, type) 
  VALUES (seq_shareholder_id.nextval,'Company')
;

INSERT INTO company 
  (company_id,name,place_id)
  VALUES (seq_shareholder_id.currval,'Makoto Investing',
  (select place_id FROM place WHERE city = 'Tokyo'))
;

--****************************************************************************************************************************************--
-- 11.     “Makoto Investing” would like to declare stock.  As of today’s date, they are authorizing 100,000 shares 
-- at a starting price of 50 yen.   
-- To complete the work, you will need to update the company table to give Makoto its own stock id, and insert 
-- a new entry in the shares_authorized table.
--****************************************************************************************************************************************--
select * from shareholder order by shareholder_id desc;
select * from company order by company_id desc;
select * from place;



create sequence seq_stock_id
  INCREMENT BY 1
  START WITH 10
;

UPDATE COMPANY com 
  SET com.stock_id = seq_stock_id.nextval, com.starting_price = 50, 
  com.currency_id = (SELECT currency_id FROM currency where name = 'Yen' ) 
  WHERE com.name = 'Makoto Investing'
;

INSERT INTO shares_authorized
 (stock_id, time_start, authorized)
VALUES (seq_stock_id.currval, SYSDATE, 100000)
;
--****************************************************************************************************************************************--
-- 12.       “Makoto Investing” would like to list on the Tokyo Stock Exchange under the stock symbol “Makoto”.  
--You will need to insert into the stock_listing table and the stock_price table.
--****************************************************************************************************************************************--


-- INSERT INTO stock_exchange (stock_ex_id,name,symbol,place_id,currency_id) VALUES (4,'Tokyo Stock Exchange','TSE',4, 5);

select * from shareholder order by shareholder_id desc;
select * from company order by company_id desc;
select * from place;
select * from stock_listing order by stock_id desc;




INSERT INTO stock_listing(stock_id, stock_ex_id, stock_symbol) 
VALUES ((select stock_id from company where name = 'Makoto Investing'), 
    (select stock_ex_id from stock_exchange where symbol = 'TSE'), 'MAKOTO');

INSERT INTO stock_price (stock_ex_id, stock_id, time_start, price) 
VALUES ((select stock_ex_id from stock_listing where stock_symbol = 'MAKOTO'), 
        (select stock_id from company where name = 'Makoto Investing'), sysdate,
        (select starting_price from company where name = 'Makoto Investing'));





--****************************************************************************************************************************************--

--Stored Procedures
--Write the necessary CREATE OR REPLACE PROCEDURE statements and statements which test your procedures.
--Add a Direct Holder

--****************************************************************************************************************************************--
--13.     Write a PL/SQL procedure called INSERT_DIRECT_HOLDER which will be used to insert new direct holders.  
--Create a sequence object on the database to automatically generate shareholder_ids. Use this sequence in your procedure. 
---Input parameters: first_name, last_name
--****************************************************************************************************************************************--
select * from shareholder order by shareholder_id desc;
select * from company order by company_id desc;
select * from place;
select * from stock_listing order by stock_id desc;
select * from direct_holder order by direct_holder_id desc;





-- AS
--   l_direct_holder_id NUMBER(6,2) NULL;
--   IF l_direct_holder_id IS NULL THEN
--      l_direct_holder_id := 1;
--   ELSE
--      l_direct_holder_id := l_direct_holder_id + 1;
--   END IF;

CREATE OR REPLACE PROCEDURE INSERT_DIRECT_HOLDER 
  (
  p_first_name IN direct_holder.first_name%type,
  p_last_name IN direct_holder.last_name%type)
AS
BEGIN

  
  INSERT INTO shareholder (shareholder_id, type)
  VALUES(seq_shareholder_id.nextval, 'Direct_Holder');

  INSERT INTO direct_holder (direct_holder_id, first_name, last_name)
  VALUES (seq_shareholder_id.currval, p_first_name, p_last_name);
  
  COMMIT;
END;
/

show errors procedure insert_direct_holder; 

EXEC insert_direct_holder('&first_name','&last_name');

EXEC insert_direct_holder('Bruce', 'Wayne');
--****************************************************************************************************************************************--
--Add an Institutional Holder
--14.     Write a PL/SQL procedure called INSERT_COMPANY which will be used to insert new companies. 
--The stock_id for new companies will be null.  Use the sequence object that you created in problem 13 to get new shareholder_ids. 
--****************************************************************************************************************************************--

select * from shareholder order by shareholder_id desc;
select * from company order by company_id desc;
select * from place;
select * from stock_listing order by stock_id desc;
select * from direct_holder order by direct_holder_id desc;




CREATE OR REPLACE PROCEDURE INSERT_COMPANY
  (
  p_name IN company.name%type,
  p_city IN place.city%type,
  p_country IN place.country%type
  )
AS
  l_place_id NUMBER(6,2) NULL;
BEGIN

  SELECT 
    place_id INTO l_place_id 
  FROM
    place
  WHERE city = p_city AND country = p_country 
 ;
 
     
  INSERT INTO shareholder (shareholder_id, type)
  VALUES(seq_shareholder_id.nextval, 'Company');
  
  
  INSERT INTO company (company_id, name, place_id)
  VALUES (seq_shareholder_id.currval, p_name, l_place_id);
  
  
  COMMIT;
END;
/

show errors procedure insert_company; 

EXEC insert_company('&name','&city','&country');
EXEC insert_company('Wayne Industries', 'New York', 'USA');


--****************************************************************************************************************************************--
-- Declare Stock (Initial Public Offering)
-- 15.     Write a PL/SQL procedure called DECLARE_STOCK which will be used when a company declares it is issuing shares. 
-- -Input parameters: company name, number of shares authorized, starting price (in the designated currency), and currency name.  
-- -Check to ensure the company has not already been given a stock id. 
-- -If the company already has a stock id then do not perform any data changes. 
-- -Otherwise, the company must be assigned a stock id (create a sequence object to generate new stock_ids) and the 
-- date of issue (current system date), number of shares authorized, the starting price and currency id must be recorded.
--****************************************************************************************************************************************--
select * from shareholder order by shareholder_id desc;
select * from company order by company_id desc;
select * from place;
select * from stock_listing order by stock_id desc;
select * from direct_holder order by direct_holder_id desc;
select * from currency;
select * from company;
select * from shares_authorized order by stock_id desc;



CREATE OR REPLACE PROCEDURE declare_stock
  (p_company_name IN company.name%type,  
   p_authorized IN shares_authorized.authorized%type,
   p_starting_price IN company.starting_price%type,
   p_currency_name IN currency.name%type
   )
AS
  l_currency_id NUMBER(6,2) NULL;
  l_stock_id NUMBER(6,2) NULL;
BEGIN

 SELECT stock_id INTO l_stock_id
 FROM company where name = p_company_name;
 
 
  IF l_stock_id IS NULL THEN
     l_stock_id := seq_stock_id.nextval;
  ELSE
     l_stock_id := l_stock_id;
  END IF;

  
 SELECT 
    currency_id INTO l_currency_id 
  FROM
    currency
  WHERE name = p_currency_name 
 ; 


  UPDATE COMPANY  
  SET   currency_id = l_currency_id, starting_price = p_starting_price, stock_id = l_stock_id
  WHERE name = p_company_name;

    INSERT INTO shares_authorized
     (stock_id, time_start, authorized)
    VALUES (seq_stock_id.currval, SYSDATE, p_authorized)
    ;
    
  COMMIT;
END;
/

  

show errors procedure declare_stock; 

EXEC declare_stock('&name','&authorized', '&starting_price', '&country');
EXEC declare_stock('Wayne Industries', 100000, 100, 'Dollar');


--****************************************************************************************************************************************--

-- Listing on an Exchange
-- 16.     Write a PL/SQL procedure called LIST_STOCK which will be used when stock is listed on a stock exchange. 
-- -Input parameters: stock_id, stock_ex_id, stock_symbol. 
-- -The stock_id, stock_ex_id and stock_symbol must be recorded in the stock_listing table. 
-- -The starting price from company must be copied to the stock price list for the stock exchange.  
-- The current system time will be used for the time_start and the time_end will be null.  
-- The procedure must be able to convert currencies as needed.

--****************************************************************************************************************************************--
select * from shareholder order by shareholder_id desc;
select * from company order by company_id desc;
select * from place;
select * from stock_listing order by stock_id desc;
select * from direct_holder order by direct_holder_id desc;
select * from currency;
select * from stock_exchange;
select * from shares_authorized order by stock_id desc;



CREATE OR REPLACE PROCEDURE list_stock
  (p_stock_id IN stock_price.stock_id%type,
  p_stock_ex_id IN stock_price.stock_ex_id%type,  
   p_stock_symbol IN stock_listing.stock_symbol%type )
AS
    l_starting_price NUMBER(6,2) NULL;
BEGIN

 SELECT 
    starting_price INTO l_starting_price 
  FROM company 
  WHERE stock_id = p_stock_id
 ; 
 
  IF l_starting_price IS NULL THEN
     l_starting_price := 1;
  ELSE
     l_starting_price := l_starting_price;
  END IF;
  
DBMS_OUTPUT.PUT_LINE('starting price of company ' || l_starting_price);
DBMS_OUTPUT.PUT_LINE('Estock exchange id of company ' || p_stock_ex_id);


INSERT INTO stock_listing(stock_id, stock_ex_id, stock_symbol) VALUES (p_stock_id, p_stock_ex_id, p_stock_symbol);

INSERT INTO stock_price (stock_id, stock_ex_id, time_start, price) VALUES (p_stock_id, p_stock_ex_id,sysdate, l_starting_price);


  COMMIT;
END;
/


show errors procedure list_stock; 

EXEC list_stock('%stock_id', '&stock_ex_id', '&stock_symbol');
EXEC list_stock(11, 3, 'BTM');




--****************************************************************************************************************************************--
-- Stock Split
-- 17.     Write a PL/SQL procedure called SPLIT_STOCK. 

-- input parameters:  stock id, split_factor 

--  The split_factor must be greater than 1 and can be fractional.  (The number of shares will be multiplied by the split_factor.) 
--  The total shares outstanding cannot exceed the authorized amount.  Your procedure should raise an application error if the 
--  split would cause the shares outstanding to exceed the shares authorized. 
--  Every shareholder must receive (is buyer of) an additional "trade" equal to the additional shares to which they are entitled.  
--  For example, if the split_factor is 2 then each shareholder will be entitled to an additional “trade” that is equal to the 
--  number of shares that they owned before the split.  (Use the Current_Shareholder_Shares view to determine the number of shares owned).
--  These "trades" will not take place at a stock exchange, the price total will be null, and there will be no brokers involved.
--****************************************************************************************************************************************--
select * from shareholder order by shareholder_id desc;
select * from company order by company_id desc;
select * from place;
select * from stock_listing order by stock_id desc;
select * from direct_holder order by direct_holder_id desc;
select * from currency;
select * from stock_exchange;
select * from shares_authorized order by stock_id desc;


drop procedure split_stock;

create or replace procedure split_stock
    (p_stock_id IN trade.stock_id%type,
    p_split_factor IN trade.stock_id%type)

AS
l_not_split NUMBER(6,2) null;
l_number NUMBER(6,2);
l_outs_share NUMBER(6,2) null;
l_authorized_amount NUMBER(6,2) null;
BEGIN
l_number := to_number(p_split_factor);
l_outs_share := 0;
IF p_split_factor > 1 then
    l_not_split := p_split_factor;
else
    -- DBMS_OUTPUT.PUT_LINE('Split factor must be greater than 1');
end if;

select ROUND(cur_stat.current_authorized  - cur_stat.total_outstanding,2) INTO l_outs_share
from current_stock_stats cur_stat
WHERE cur_stat.stock_id = p_stock_id and cur_stat.total_outstanding is not null;

-- DBMS_OUTPUT.PUT_LINE('Enter shares, can not exceed authorized amount' || l_outs_share);

commit;
END;
/

SHOW ERROR PROCEDURE SPLIT_STOCK
exec split_stock('&stock_id', '&split_factoring');

exec split_stock(1, 2);

SELECT (cur_stat.current_authorized) - cur_stat.total_outstanding) 
FROM current_stock_stats cur_stats
where stock_id = 1
;


--****************************************************************************************************************************************--

-- Additional Queries
-- 19.     Display the trade id, the stock id and the total price (in US dollars) for 
-- the secondary market trade with the highest total price.  Convert all prices to US dollars.

--****************************************************************************************************************************************--

CREATE or replace view company_view AS(
select 
  tr.trade_id as trade_id,
  tr.stock_ex_id as stock_ex_id,
  com.name as name,
  com.stock_id as stock_id,
  tr.shares as shares,
  tr.price_total as total
from company com 
  LEFT JOIN trade tr 
    ON com.stock_id = tr.stock_id
WHERE com.stock_id IS NOT NULL 
AND tr.stock_ex_id IS NOT NULL
GROUP BY   tr.trade_id, 
  tr.stock_ex_id,
  com.name,
  com.stock_id,
  tr.shares,
  tr.price_total)
;





WITH USDOLLAR (
  select 
    tr.stock_id as stockid, 
    se.currency_id as currnecyid,
    MAX(tr.price_total) as highest
  FROM trade tr
    LEFT JOIN stock_exchange se
      ON se.stock_ex_id = tr.stock_ex_id
  GROUP BY 
    tr.stock_id as stockid, 
    se.currency_id as currnecyid
  )

SELECT 
  created.stock_id,
  ROUND(CASE WHEN created.currency_id = 1 THEN 
    created.highest
    ELSE 
    created.highest * (select 
                        con.exchange_rate 
                        FROM conversion con 
                        where con.from_currency_id = 2
                        AND con.to_currency_id = 1 ) end, 2) as ALOT_WORK__FOR_CURRENCY_EXCHANGE
FROM USDOLLAR created
  LEFT JOIN currency cur
    ON cur.currency_id = created.currency_id
WHERE cur.currency_id IS NOT null
;







--============================================ old one  =======================================================--

-- SELECT 
--  tr.trade_id,
--  tr.stock_id,
--  tr.transaction_time AS "Transaction Date",
-- --  to_char(tr.price_total, '999,999,999.99') AS "Price Total",
--  to_char(SUM(tr.price_total*con.exchange_rate), '999,999,999.99') AS "Amount" 
-- FROM company com 
--  JOIN trade tr
--   ON com.stock_id = com.stock_id
--    JOIN stock_listing sl
--     ON tr.stock_ex_id = sl.stock_ex_id
--      JOIN shares_authorized sa
--       ON sl.stock_id = sa.stock_id
--        JOIN stock_price sp
--         ON sa.stock_id = sp.stock_id
--          JOIN stock_exchange se 
--           ON sp.stock_ex_id = se.stock_ex_id
--            JOIN currency cur
--             ON se.currency_id = cur.currency_id
--              JOIN conversion con
--               ON cur.currency_id = con.from_currency_id
-- WHERE trunc(tr.transaction_time,'dd') = trunc(sp.time_start,'dd')
-- GROUP BY tr.trade_id, tr.stock_id, tr.transaction_time
-- ;




--****************************************************************************************************************************************--

-- 20.     Display the name of the company and trade volume for the company whose stock has the largest 
-- total volume of shareholder trades worldwide. [Example calculation: A company declares 20000 shares, and issues 10000 on the new 
-- issue market (primary market), and 1000 shares is sold to a stockholder on the secondary market. Later that stockholder sells 500 shares to 
-- another stockholder (or back to the company itself).  The number of shareholder trades is 2 and the total volume of shareholder trades is 1500.]

--****************************************************************************************************************************************--
CREATE or replace view company_view AS(
select 
  tr.trade_id,
  tr.stock_ex_id,
  com.name,
  com.stock_id,
  tr.shares,
  tr.price_total
from company com 
  LEFT JOIN trade tr 
    ON com.stock_id = tr.stock_id
WHERE com.stock_id IS NOT NULL 
AND tr.stock_ex_id IS NOT NULL
GROUP BY   tr.trade_id, 
  tr.stock_ex_id,
  com.name,
  com.stock_id,
  tr.shares,
  tr.price_total)
;

--============================================ views on top =======================================================--

SELECT 
  created.trade_id,
  created.name,
  created.stock_id,
  created.shares,
  created.price_total,
  MAX(created.shares)
FROM company_view created
  LEFT JOIN stock_price sp 
    ON sp.stock_id = created.stock_id
    AND created.stock_ex_id = sp.stock_ex_id
WHERE sp.stock_id IS NOT NULL
AND sp.stock_ex_id IS NOT NULL
GROUP BY 
  created.trade_id,
  created.name,
  created.stock_id,
  created.shares,
  created.price_total
;


--============================================ old one  =======================================================--

-- SELECT 
--  tr.trade_id,
--  tr.stock_id,
--  SUM(tr.shares * con.exchange_rate) AS "Amount Exchanged"
-- FROM company com 
--  JOIN trade tr
--   ON com.stock_id = com.stock_id
--    JOIN stock_listing sl
--     ON tr.stock_ex_id = sl.stock_ex_id
--      JOIN shares_authorized sa
--       ON sl.stock_id = sa.stock_id
--        JOIN stock_price sp
--         ON sa.stock_id = sp.stock_id
--          JOIN stock_exchange se 
--           ON sp.stock_ex_id = se.stock_ex_id
--            JOIN currency cur
--             ON se.currency_id = cur.currency_id
--              JOIN conversion con
--               ON cur.currency_id = con.from_currency_id
-- WHERE trunc(tr.transaction_time,'dd') = trunc(sp.time_start,'dd')
-- GROUP BY tr.trade_id, tr.stock_id
-- ;

--============================================ old one  =======================================================--




--****************************************************************************************************************************************--
-- 21.     For each stock exchange, display the symbol of the stock with the highest total trade volume. Show the stock exchange name, 
-- stock symbol and total trade volume.  Sort the output by the name of the stock exchange and stock symbol.
--****************************************************************************************************************************************--


-- SELECT 
--   tr.stock_id,
--   tr.stock_ex_id,
--   .name,



-- Create OR replace view tr_view 
-- AS 
-- SELECT 
--   tr.stock_ex_id,
--   tr.stock_id,
--   MAX(tr.stock_ex_id)
-- FROM trade tr
-- WHERE tr.stock_ex_id IS NOT NULL
-- GROUP BY tr.stock_ex_id, tr.stock_id
-- ;










-- SELECT
--   st.symbol AS "Stock Exchange Symbol",
--   curr.name AS "Currency",
--   TO_CHAR(AVG(tr.shares*stp.price),'999,999,999.99') AS "Average Trade Size"
-- FROM trade tr
--   JOIN stock_exchange st
--     ON tr.stock_ex_id = st.stock_ex_id
--   JOIN currency curr
--     ON st.currency_id = curr.currency_id
--   JOIN stock_price stp
--     ON tr.stock_id = stp.stock_id
--     AND tr.stock_ex_id = stp.stock_ex_id
--     AND trunc(tr.transaction_time,'dd') = trunc(stp.time_start,'dd')
-- GROUP BY st.symbol, curr.name
-- ;


SELECT 
 se.name,
 se.symbol AS "Stock Exchange Symbol",
 sl.stock_symbol,
 COUNT(tr.shares) "Trades"
 FROM trade tr
   JOIN stock_listing sl
    ON tr.stock_ex_id = sl.stock_ex_id
     JOIN shares_authorized sa
      ON sl.stock_id = sa.stock_id
       JOIN stock_price sp
        ON sa.stock_id = sp.stock_id
         JOIN stock_exchange se 
          ON sp.stock_ex_id = se.stock_ex_id
           JOIN currency cur
            ON se.currency_id = cur.currency_id

WHERE trunc(tr.transaction_time,'dd') = trunc(sp.time_start,'dd')
GROUP BY se.name, se.symbol, sl.stock_symbol
;

--****************************************************************************************************************************************--
-- 22.     List the top 5 companies (in terms of shareholder trade volume) on the New York Stock Exchange.  
-- Display the company name, shareholder trade volume, the current price and the percentage change for 
-- the last price change, and sort the output in descending order of shareholder trade volume.  The sample data in the database contains 
-- information for only 3 companies but your query must continue to list only the top 5 companies even when there is data for more companies.
--****************************************************************************************************************************************--




SELECT 
  ROWNUM,
  tr.trade_id, 
  com.name,
  tr.buyer_id,
  MAX(tr.shares) AS Forbes
  
FROM stock_exchange se 
  LEFT JOIN trade tr 
    ON tr.stock_ex_id = se.stock_ex_id 
WHERE se.symbol = 'NYSE' AND rownum > 4
GROUP BY tr.trade_id, com.name, tr.buyer_id
ORDER by forbes desc
;





--============================================old one============================================================--
-- SELECT DISTINCT
--  com.stock_id,
--  com.name,
--  tr.shares
-- FROM stock_price sp
--  JOIN company com 
--   ON com.stock_id = sp.stock_id
--     JOIN trade tr
--      ON com.stock_id = tr.stock_id
--       JOIN shares_authorized sa
--        ON tr.stock_id = sa.stock_id
--         JOIN stock_price sp
--          ON sa.stock_id = sp.stock_id
--           JOIN stock_exchange se 
--            ON sp.stock_ex_id = se.stock_ex_id
-- ORDER BY tr.shares,sp.price, com.stock_id, com.name

-- ;

--===============================================================================================================--


