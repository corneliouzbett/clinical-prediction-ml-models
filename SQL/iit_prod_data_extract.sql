-- ML query
-- Calculate rolling default numbers
with num_2wk_defaults_last_3_visits as (
    select
        dd1.person_id,
        dd1.encounter_id,
        dd1.visit_number,
        if(dd2.days_defaulted_last_encounter >= 14, 1, 0) +
        if(dd3.days_defaulted_last_encounter >= 14, 1, 0) +
        if(dd4.days_defaulted_last_encounter >= 14, 1, 0) as num_2wks_defaults_last_3visits
    from predictions.flat_ml_days_defaulted dd1
             left join predictions.flat_ml_days_defaulted dd2
                       on dd2.person_id = dd1.person_id
                           and dd2.encounter_id = dd1.encounter_id
                           and dd2.visit_number = dd1.visit_number - 1
             left join predictions.flat_ml_days_defaulted dd3
                       on dd3.person_id = dd2.person_id
                           and dd3.encounter_id = dd2.encounter_id
                           and dd3.visit_number = dd2.visit_number - 1
             left join predictions.flat_ml_days_defaulted dd4
                       on dd4.person_id = dd3.person_id
                           and dd4.encounter_id = dd3.encounter_id
                           and dd4.visit_number = dd3.visit_number - 1
),
defaults_by_days as (
    select
        dd.person_id,
        dd.encounter_id,
        encounter_date,
        max(dd.days_defaulted_last_encounter) as days_defaulted
    from predictions.flat_ml_days_defaulted dd
    group by dd.person_id, encounter_date
 )
-- describe the columns we need
select
    fs.person_id,
    fs.encounter_id,
    fs.encounter_type,
    fs.location_id,
    fs.rtc_date,
    timestampdiff(YEAR, p.birthdate, fs.encounter_datetime) as Age,
    if(p.birthdate is null, 1, 0) as Age_NA,
    p.gender as Gender,
    null as Marital_status,
    timestampdiff(year,
        if(year(fs.arv_first_regimen_start_date) != 1900,
            date(fs.arv_first_regimen_start_date),
            null
        ),
        date(fs.encounter_datetime)
    ) as Duration_in_HIV_care,
    if(fs.arv_first_regimen_start_date is null or year(fs.arv_first_regimen_start_date) = 1900,
       1, 0) as Duration_in_HIV_care_NA,
    case
        when fs.weight is null or fs.height is null or fs.weight < 1 or fs.height < 1
            then null
        when round(fs.weight / ((fs.height / 100) * (fs.height / 100)), 2) < 5.0
            then null
        when round(fs.weight / ((fs.height / 100) * (fs.height / 100)), 2) > 60.0
            then null
        else round(fs.weight / ((fs.height / 100) * (fs.height / 100)), 2)
    end as BMI,
    case
        when fs.weight is null or fs.height is null or fs.weight < 1 or fs.height < 1
            then 1
        when round(fs.weight / ((fs.height / 100) * (fs.height / 100)), 2) < 5.0
            then 1
        when round(fs.weight / ((fs.height / 100) * (fs.height / 100)), 2) > 60.0
            then 1
        else 0
    end as BMI_NA,
    null as Travel_time,
    fs.cur_who_stage as WHO_staging,
    if(fs.cur_who_stage is null, 1, 0) as WHO_staging_NA,
    log10(fs.vl_resulted + 1) as Viral_Load_log10,
    if(fs.vl_resulted is null, 1, 0) as Viral_Load_log10_NA,
    if(fs.vl_resulted < 1000, 1, 0) as VL_suppression,
    timestampdiff(DAY, fs.encounter_datetime, fs.vl_resulted_date) as Days_Since_Last_VL,
    fs.hiv_status_disclosed as HIV_disclosure,
    if(fs.hiv_status_disclosed is null, 1, 0) as HIV_disclosure_NA,
    -- NB Regimen Line differs from extraction data
    fs.cur_arv_line as Regimen_Line,
    if(fs.cur_arv_line is null, 1, 0) as Regimen_Line_NA,
    coalesce(fs.is_pregnant, 0) as Pregnancy,
    case
        when fs.location_id in (55, 315, 19, 230, 26, 23, 319, 130, 313, 9, 78, 310, 20, 312, 12, 321, 8, 341)
            then 'Urban'
        when fs.location_id in (65, 314, 64, 83, 316, 90, 135, 106, 86, 336, 91, 320, 74, 76, 79, 100, 311, 75)
            then 'Rural'
        end as Clinic_Location,
    null as TB_Comorbidity,
    fs.cd4_resulted as CD4,
    if(fs.cd4_resulted is null, 1, 0) as CD4_NA,
    datediff(fs.encounter_datetime, fs.cd4_resulted_date) as Days_Since_Last_CD4,
    null as Entry_Point,
    case
        when et.name in ('ADULTINITIAL', 'PEDSINITIAL', 'YOUTHINITIAL') then 'Initial'
        when et.name in ('ADULTRETURN', 'PEDSRETURN', 'YOUTHRETURN') then 'Return'
        else 'Other'
        end as Encounter_Type_Class,
    null as Education_Level,
    null as Occupation,
    null as Adherence_Counselling_Sessions,
    l.name as Clinic_Name,
    replace(etl.get_arv_names(fs.cur_arv_meds), '##', '+') as ART_regimen,
    dd.visit_number as Visit_Number,
    days_defaulted_last_encounter as Days_defaulted_in_prev_enc,
    if(days_defaulted_last_encounter is null, 1, 0) as Days_defaulted_in_prev_enc_NA,
    num_2wks_defaults_last_3visits,
    if(num_2wks_defaults_last_3visits is null, 1, 0) as num_2wks_defaults_last_3visits_NA,
    coalesce(any_30d_defaults_1yr, 0) as ever_defaulted_by_1m_in_last_1year,
    if(any_30d_defaults_1yr is null, 1, 0) as ever_defaulted_by_1m_in_last_1year_NA,
    coalesce(any_30d_defaults_2yr, 0) as ever_defaulted_by_1m_in_last_2year,
    if(any_30d_defaults_2yr is null, 1, 0) as ever_defaulted_by_1m_in_last_2year_NA,
    Age_baseline,
    Gender_baseline,
    Marital_status_baseline,
    BMI_baseline,
    Travel_time_baseline,
    WHO_staging_baseline,
    VL_suppression_baseline,
    Viral_Load_log10_baseline,
    HIV_disclosure_baseline,
    Regimen_Line_baseline,
    Pregnancy_baseline,
    Clinic_Location_baseline,
    TB_Comorbidity_baseline,
    CD4_baseline,
    Education_Level_baseline,
    Occupation_baseline,
    Adherence_Counselling_Sessions_baseline,
    Clinic_Name_baseline,
    ART_regimen_baseline
from flat_hiv_summary_v15b as fs
    left join predictions.flat_ml_baseline_visit baseline
        on fs.person_id = baseline.person_id
    left join predictions.flat_ml_days_defaulted dd
        on dd.encounter_id = fs.encounter_id
            and dd.person_id = fs.person_id
    join amrs.person p on p.person_id = fs.person_id
    left join amrs.encounter_type et on fs.encounter_type = et.encounter_type_id
    left join amrs.location l
        on fs.location_id = l.location_id
            and l.retired = 0
    left join num_2wk_defaults_last_3_visits 2wk_defaults
        on 2wk_defaults.person_id = fs.person_id
            and 2wk_defaults.encounter_id = fs.encounter_id
    left join (
        select person_id, if(days_defaulted >= 30, 1, 0) as any_30d_defaults_1yr
        from defaults_by_days
        where encounter_date between date_sub('2023-06-19', interval 1 year) and '2023-06-19'
        group by person_id
    ) as 1yr on 1yr.person_id = fs.person_id
    left join (
        select person_id, if(days_defaulted >= 30, 1, 0) as any_30d_defaults_2yr
        from defaults_by_days
        where encounter_date between date_sub('2023-06-19', interval 2 year) and '2023-06-19'
        group by person_id
    ) as 2yr on 2yr.person_id = fs.person_id
    left join predictions.ml_weekly_predictions mlp
        on mlp.encounter_id = fs.encounter_id
-- filtered to Dumisha clinics only, for now
where fs.location_id in (26,23,319,130,313,9,78,310,20,312,12,321,8,341,65,314,64,83,90,106,86,336,91,320,74,76,79,100,311,75)
  -- test locations
  and fs.location_id not in (195, 429, 430, 354)
  -- filter encounters: 111 - LabResult, 99999 - lab encounter type
  -- these encounters are post-visit lab result entries and should not appear in predicted data
  and fs.encounter_type not in (111, 99999)
  -- ET 116 - Transfer Encounter; 9998 - transfer expected to AMPATH clinic
  and (fs.encounter_type != 116 or fs.transfer_in_location_id = 9998)
  -- 9999 - transfered to non-AMPATH clinic, we discount these for the list of patient's that we care about trying to
  -- proactively follow-up on since we do not anticipate these patient's returning to AMPATH. If they do, they will be
  -- returned to normal status at whatever clinic they visit
  and (fs.transfer_in_location_id is null or fs.transfer_in_location_id != 9999)
  -- only include drug pickups if a return visit is not also scheduled for the same day
  and (fs.encounter_type != 186 or not exists (
    select *
    from etl.flat_hiv_summary_v15b fs_
    where fs.person_id = fs_.person_id
      and fs.rtc_date = fs_.rtc_date
      and fs_.encounter_type not in (186, 111, 99999)
      and fs_.is_clinical_encounter = 1
  ))
  and fs.is_clinical_encounter = 1
  and fs.rtc_date between ?startDate and ?endDate
  -- for retrospective data
  and fs.encounter_datetime < fs.date_created
  and (fs.next_clinical_datetime_hiv >= fs.date_created
    or fs.next_clinical_datetime_hiv is null)
  and mlp.encounter_id is null;
