create table if not exists shipping_country_rates (
shipping_country_id serial not null,
shipping_country text null,
shipping_country_base_rate numeric(14,3),
primary key (shipping_country_id),
constraint shipping_country_rates_unique unique (shipping_country, shipping_country_base_rate)
)

create table if not exists public.shipping_agreement (
	agreementid int4 not null,
	agreement_number text null,
	agreement_rate numeric(14, 3) null,
	agreement_commission numeric(14, 3) null,
	primary key (agreementid)
);

create table if not exists public.shipping_transfer (
	transfer_type_id serial not null,
	transfer_type text null,
	transfer_model text null,
	shipping_transfer_rate numeric(14, 3) null,
	primary key (transfer_type_id)
);

create table if not exists public.shipping_info(
shipping int4 primary key not null,
vendorid int4 null,
payment_amount numeric(14,3) null,
shopping_plan_datetime timestamp null,
transfer_type_id int4 null,
shipping_country_id int4 null,
agreementid int4 null,
foreign key (transfer_type_id) references shipping_transfer(transfer_type_id) on update cascade,
foreign key (shipping_country_id) references shipping_country_rates(shipping_country_id) on update cascade,
foreign key (agreementid) references shipping_agreement(agreementid) on update cascade
)
alter table public.shipping_info rename shipping to  shippingid
alter table public.shipping_info add column shipping_plan_datetime timestamp null
alter table public.shipping_info add column hours_to_plan_shipping  numeric(14,2) null
alter table public.shipping_info drop column shopping_plan_datetime

create table if not exists public.shipping_status (
	shippingid int8 not null,
	status text null,
	state text null,
	shipping_start_fact_datetime timestamp null,
	shipping_end_fact_datetime timestamp null,
	primary key (shippingid)
);

create or replace view public.shipping_datamart as 
select 
	si.shippingid
	, si.vendorid
	, st.transfer_type 
	, extract(day from age(ss.shipping_end_fact_datetime, ss.shipping_start_fact_datetime)) as full_day_at_shipping 
	, case 
		when ss.shipping_end_fact_datetime > si.shipping_plan_datetime then 1 
		else 0
	end as is_delay
	, case
		when ss.status = 'finished' then 1
		else 0
	end as is_shipping_finish 
	, case
		when ss.shipping_end_fact_datetime > (si.shipping_plan_datetime + concat(si.hours_to_plan_shipping, ' hours')::interval)
		then extract(day from age(ss.shipping_end_fact_datetime, si.shipping_plan_datetime))
		else 0
	end as delay_day_at_shipping 
	, si.payment_amount 
	, si.payment_amount * (scr.shipping_country_base_rate + sa.agreement_rate + st2.shipping_transfer_rate) as vat 
	, si.payment_amount * sa.agreement_commission as profit 
from public.shipping_info si 
	left join public.shipping_status ss on ss.shippingid = si.shippingid 
	left join public.shipping_transfer st on st.transfer_type_id = si.transfer_type_id 
	left join public.shipping_country_rates scr on scr.shipping_country_id = si.shipping_country_id 
	left join public.shipping_agreement sa on sa.agreementid = si.agreementid 
	left join public.shipping_transfer st2 on st2.transfer_type_id = si.transfer_type_id 
;

select *
from public.shipping_info

