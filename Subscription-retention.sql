create Database subscription_retention;

use subscription_retention;

-- Create table customers:
create table customers(
customer_id varchar(10) primary key,
full_name varchar(100),
email varchar(100),
phone VARCHAR(20),
city varchar(50),
age int,
gender varchar(10),
signup_date Date,
referral_source varchar(50)
);

-- Drop table customers;
select * from customers;

-- Create table subscriptions:
create table subscriptions(
subscription_id varchar(10) Primary key,                           
customer_id varchar(10),
plan_name varchar(20),
billing_cycle varchar(20),
price_inr Decimal(10,2),
start_date varchar(20),
end_date varchar(20),
status varchar(20),
auto_renew boolean,
cancellation_reason varchar(100),
Foreign key (customer_id) References customers(customer_id)
);
    
UPDATE subscriptions
SET start_date_new = STR_TO_DATE(start_date, '%d-%m-%Y'),
end_date_new = STR_TO_DATE(end_date, '%d-%m-%Y')
WHERE start_date IS NOT NULL 
AND end_date IS NOT NULL
AND start_date != ''
AND end_date != '';

SELECT start_date_new, end_date_new FROM subscriptions LIMIT 10;

ALTER TABLE subscriptions DROP COLUMN start_date;
ALTER TABLE subscriptions DROP COLUMN end_date;
ALTER TABLE subscriptions CHANGE start_date_new start_date DATE;
ALTER TABLE subscriptions CHANGE end_date_new end_date DATE;

-- drop table subscriptions;
select * from subscriptions;

-- Create table payments:
CREATE TABLE payments (
payment_id VARCHAR(12) PRIMARY KEY,
subscription_id  VARCHAR(10),
customer_id  VARCHAR(10),
payment_date DATE,
amount_inr  DECIMAL(10,2),
payment_method  VARCHAR(30),
payment_status  VARCHAR(10),
gateway VARCHAR(30),
FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
FOREIGN KEY (subscription_id) REFERENCES subscriptions(subscription_id)
);

-- drop table payments;
select  * from payments;

-- Create table viewing_activity:
create table viewing_activity(
view_id varchar(12) primary key,
customer_id  VARCHAR(10),
subscription_id  VARCHAR(10),
watch_date varchar(20),
genre varchar(30),
platform varchar(20),
duration_mins int,
content_type varchar(20),
completed varchar(20),
FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
FOREIGN KEY (subscription_id) REFERENCES subscriptions(subscription_id)
);

-- drop table viewing_activity;
select * from viewing_activity;



-- SECTION 1 : BASIC CHURN ANALYSIS


-- 1.1  Overall churn rate

select count(*)  as total_subsccriptions,
	sum(case when status = 'cancelled' then 1 else 0 End) as churned,
    sum(case when status = 'Active' then 1 else 0 End) as Active,
    Round(
    sum(case when status = 'cancelled' then 1 else 0 End) * 100.0 / count(*),2) as churn_rate_pct
    from subscriptions;
    
-- 1.2  Churn count by plan

select plan_name, count(*) as total,
	sum(case when status='cancelled' then 1 else 0 End) as churned,
    sum(case when status='Active' then 1 else 0 End) as Active,
	Round(
		sum(case when status = 'cancelled' then 1 else 0 End) * 100.0 / count(*),2) as churn_rate_pct
    from subscriptions
    group by plan_name
    order by churn_rate_pct Desc;
    
    SELECT plan_name, COUNT(*) AS total,
    SUM(status = 'cancelled') AS churned,
    SUM(status = 'Active') AS active,
    ROUND(SUM(status = 'cancelled') * 100.0 / COUNT(*), 2) AS churn_rate_pct
FROM subscriptions
GROUP BY plan_name
ORDER BY churn_rate_pct DESC;
    
    
-- 1.3  Churn by cancellation reason

select coalesce(cancellation_reason, "Not Provided") as reason, 
count(*) as total_churned
FROM subscriptions
where status ="cancelled"
group by reason
order by total_churned Desc;

-- 1.4  Churn by city

select c.city,  count(s.subscription_id) as total_subs,
	sum(s.status= "cancelled") as churned,
	Round(sum(status = "cancelled")*100.0/count(*),2) as churn_rate_pct
from subscriptions s
Join customers c on s.customer_id = c.customer_id
group by c.city
order by churn_rate_pct Desc;
    

-- 1.5  Churn by billing cycle

select billing_cycle, count(*) as total,
	sum(status="cancelled") as churned,
    round(sum(status="cancelled")*100.0/count(*),2) as churn_rate_pct
from subscriptions
group by billing_cycle
order by churn_rate_pct Desc;
    
    
-- 1.6  Monthly churn trend

select Date_format(end_date,'%Y-%m') as churn_month, count(*) churned_count
from subscriptions
where status="cancelled" and end_date is Not null
group by churn_month
order by churn_month;

-- 1.7  Average days a customer stayed before cancelling

select plan_name, 
	round(avg(datediff(end_date, start_date)),1) as avg_days_before_churn
from subscriptions
where status="cancelled" and end_date is not null
group by plan_name
order by avg_days_before_churn Desc;


-- SECTION 2 : REVENUE & PAYMENT ANALYSIS

-- 2.1  Total revenue collected vs failed

select 
sum(case when payment_status="success" then amount_inr else 0 end) as total_revenue_inr,
sum(case when payment_status="Failed" then amount_inr else 0 end) as failed_revenue_inr,
count(payment_status="Failed") as Failed_payment_count
from payments;

-- 2.2  Monthly revenue trend

select date_format(payment_date,'%Y-%m') as pay_month,
sum(case when payment_status="success" then amount_inr else 1 end) as revenue_inr,
count(case when payment_status = "failed" then 1 end) as failed_count
from payments
Group by pay_month
order by pay_month; 

-- 2.3  Revenue by plan

select s.plan_name, count(distinct p.payment_id) as total_payments,
sum(case when p.payment_status="success" then p.amount_inr else 0 end) as revenue_inr
from payments p 
join subscriptions s on p.subscription_id = s.subscription_id
group by s.plan_name
order by revenue_inr Desc;

-- 2.4  Payment failure rate by gateway

select gateway, count(*) as total_payments,
sum(case when payment_status= "Failed" then 1 else 0 End) as failed_count,
round(sum(case when payment_status= "failed" then 1 else 0 end)*100.0/count(*),2)  as failure_rate_pct
from payments
group by gateway
order by failure_rate_pct Desc;


-- 2.5  Payment method popularity

select payment_method, count(*) as usage_count,
round(count(*)*100.0/(select count(*) from payments),2) as usage_pct
from payments
group by payment_method
order by usage_count Desc;


-- SECTION 3 : CUSTOMER ENGAGEMENT (VIEWING)
-- ============================================================

-- 3.1  Total watch sessions and hours by plan

select s.plan_name , count(v.view_id) as total_sessions,
round(sum(v.duration_mins)/60,1) as total_hours_watched,
round(avg(v.duration_mins),1) as avg_session_mins
from viewing_activity v
join subscriptions s on v.subscription_id = s.subscription_id
group by s.plan_name
order by total_hours_watched Desc;

-- 3.2  Most watched genres

SELECT genre, count(*) as sessions,
round(avg(duration_mins),2) as avg_mins,
round(sum(completed)*100.0/count(*),2) as completion_rate_pct
from viewing_activity
group by genre
order by sessions Desc;

-- 3.3  Platform usage breakdown

select platform, count(*) as sessions,
round(avg(duration_mins),2) as avg_mins
from viewing_activity
group by platform
order by sessions Desc;

-- 3.4  Content type preference

select content_type, count(*) as sessions,
round(sum(completed) * 100.0 / count(*), 2) as completion_rate_pct
from viewing_activity
group by content_type
order by sessions desc;

-- 3.5  Customers with no viewing activity (churned without engaging)

select c.customer_id, c.full_name, c.city, s.plan_name, s.status, s.cancellation_reason
from customers c
join subscriptions s ON c.customer_id = s.customer_id
left join viewing_activity v ON c.customer_id = v.customer_id
where v.view_id is null 
order by s.status;





