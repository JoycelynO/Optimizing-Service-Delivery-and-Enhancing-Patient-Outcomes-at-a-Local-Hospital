--Data Cleaning

--Cleaning Patients table
SELECT *
FROM [Patients Table]

-- Remove null rows in patients table
DELETE FROM [Patients Table]
WHERE patient_id IS NULL
AND patient_name IS NULL
AND date_of_birth IS NULL
AND gender IS NULL
AND address IS NULL;

-- Drop empty columns
ALTER TABLE [Patients Table]
DROP COLUMN column6, column7, column8, column9
; 

SELECT *
FROM [Patients Table];

-- Checking for duplicates
WITH rownum AS(
	SELECT *,
	ROW_NUMBER() OVER(PARTITION BY patient_id
	ORDER BY patient_id) as row_num
	FROM [Patients Table]
	) 

SELECT *
FROM rownum
WHERE row_num > 1;

---------------------------------------------------------------------------------------------------

-- Cleaning Outpatient Visits table
SELECT *
FROM [Outpatient Visits]

-- Replacing null values
UPDATE [Outpatient Visits]
SET diagnosis = 'N/A'
WHERE diagnosis IS NULL

UPDATE [Outpatient Visits]
SET medication_prescribed = 'N/A'
WHERE medication_prescribed IS NULL

SELECT *
FROM [Outpatient Visits];

--Checking for duplicates
WITH opd_rownum AS(
	SELECT *,
	ROW_NUMBER() OVER(PARTITION BY visit_id,
								patient_id,
								visit_date
					ORDER BY patient_id) as row_num_opd
	FROM [Outpatient Visits]
	) 

SELECT *
FROM opd_rownum
WHERE row_num_opd > 1;

---------------------------------------------------------------------------------------------------

--Cleaning Hospital Records
SELECT *
FROM [Hospital Records];

--Checking for duplicates
WITH rec_rownum AS(
	SELECT *,
	ROW_NUMBER() OVER(PARTITION BY 
								patient_id
					ORDER BY patient_id) as row_num_rec
	FROM [Hospital Records]
	) 

SELECT *
FROM rec_rownum
WHERE row_num_rec > 1;

---------------------------------------------------------------------------------------------------

--Cleaning Lab results table
SELECT *
FROM [Lab Results];

--Checking for duplicates
WITH lab_rownum AS(
	SELECT *,
	ROW_NUMBER() OVER(PARTITION BY result_id,
								visit_id,
								test_date
					ORDER BY result_id) as row_num_lab
	FROM [Lab Results]
	) 

SELECT *
FROM lab_rownum
WHERE row_num_lab > 1;

---------------------------------------------------------------------------------------------------

--Cleaning Appointment Analysis table
SELECT *
FROM [Appointment Analysis]

-- Remove null rows in appointment analysis table
DELETE FROM [Appointment Analysis]
WHERE visit_id IS NULL
AND patient_id IS NULL
AND department_name IS NULL
AND patient_name IS NULL
AND appointment_date IS NULL
AND arrival_time IS NULL
AND appointment_time IS NULL
AND admission_time IS NULL
;

SELECT *
FROM [Appointment Analysis];

--Check for duplicates
WITH app_rownum AS(
	SELECT *,
	ROW_NUMBER() OVER(PARTITION BY visit_id,
								patient_id,
								appointment_date
					ORDER BY visit_id) as row_num_app
	FROM [Appointment Analysis]
	) 

SELECT *
FROM app_rownum
WHERE row_num_app > 1;



---------------------------------------------------------------------------------------------------
-- Data Analysis

-- What is the demographic profile of the patient population, including age and gender distribution?

SELECT gender,
CASE WHEN DATEDIFF(year, date_of_birth, GETDATE()) BETWEEN 0 AND 17 THEN 'Pediatric'
	 WHEN DATEDIFF(year, date_of_birth, GETDATE()) BETWEEN 18 AND 64 THEN 'Adult'
	 ELSE 'Senior' END AS patient_category,
	 COUNT(patient_id) AS patient_count
FROM [Patients Table]
GROUP BY gender, 
CASE WHEN DATEDIFF(year, date_of_birth, GETDATE()) BETWEEN 0 AND 17 THEN 'Pediatric'
	 WHEN DATEDIFF(year, date_of_birth, GETDATE()) BETWEEN 18 AND 64 THEN 'Adult'
	 ELSE 'Senior' END
;


--Which diagnoses are most prevalent among patients, and how do they vary across different demographic groups, including gender and age?
SELECT p.gender,
	   opd.diagnosis,
CASE WHEN DATEDIFF(year, date_of_birth, GETDATE()) BETWEEN 0 AND 17 THEN 'Pediatric'
	 WHEN DATEDIFF(year, date_of_birth, GETDATE()) BETWEEN 18 AND 64 THEN 'Adult'
	 ELSE 'Senior' END AS patient_category,
	 COUNT(p.patient_id) AS patient_count
FROM [Patients Table] AS p
INNER JOIN [Outpatient Visits] AS opd
ON p.patient_id = opd.patient_id
WHERE opd.diagnosis <> 'N/A'
GROUP BY p.gender, opd.diagnosis,
CASE WHEN DATEDIFF(year, date_of_birth, GETDATE()) BETWEEN 0 AND 17 THEN 'Pediatric'
	 WHEN DATEDIFF(year, date_of_birth, GETDATE()) BETWEEN 18 AND 64 THEN 'Adult'
	 ELSE 'Senior' END
ORDER BY patient_count DESC;


--What are the most common appointment times throughout the day, and how does the distribution of apppointment times vary across different hours?

SELECT DATENAME(DW, appointment_date) AS day_of_week,  
	   DATEPART (hour, appointment_time) AS appointment_hour,
	   COUNT (*) AS num_of_appointments
FROM [Appointment Analysis]
GROUP BY DATENAME(DW, appointment_date),
		 DATEPART(hour, appointment_time)
ORDER BY num_of_appointments DESC;


--What are the most commonly ordered lab tests?

SELECT test_name,
	   COUNT (result_id) AS num_of_tests
FROM [Lab Results]
GROUP BY test_name
ORDER BY num_of_tests DESC;
	 


/*Typically, fasting blood sugar levels falls between 70-100 mg/dL. Our goal is to identify patients 
whose lab results are outside this normal range to implement early intervention.*/

Select P.patient_id,
	   P.patient_name,
       L.test_name,
	   ROUND(L.result_value, 2)
FROM [Lab Results] AS L
INNER JOIN [Outpatient Visits] AS O
ON L.visit_id = O.visit_id
INNER JOIN [Patients Table] AS P
ON O.patient_id = P.patient_id
WHERE (test_name = 'Fasting Blood Sugar')
AND (result_value < 70 OR result_value > 100);


--Assess how many patients are considered High, Medium, and Low Risk.

/*High Risk: patients who are smokers and have been diagnosed with either hypertension or diabetes
Medium Risk: patients who are non-smokers and have been diagnosed with either hypertension or diabetes
Low Risk: patients who do not fall into the High or Medium Risk categories. This includes patients who are not
smokers and do not have a diagnosis of hypertension or diabetes*/

SELECT
CASE WHEN smoker_status = 1 AND (diagnosis ='Hypertension' OR diagnosis = 'Diabetes') THEN 'High Risk'
	 WHEN smoker_status = 0 AND (diagnosis = 'Hypertension' OR diagnosis = 'Diabetes') THEN 'Medium Risk'
	 ELSE 'Low Risk' END AS risk_category,
	 COUNT (patient_id) AS patient_count
FROM [Outpatient Visits]
GROUP BY CASE WHEN smoker_status = 1 AND (diagnosis ='Hypertension' OR diagnosis = 'Diabetes') THEN 'High Risk'
	 WHEN smoker_status = 0 AND (diagnosis = 'Hypertension' OR diagnosis = 'Diabetes') THEN 'Medium Risk'
	 ELSE 'Low Risk' END
ORDER BY patient_count DESC;


/*Find out information about the patients who had multiple visits within 30 days of their previous medical visit
- Identify those patients
- Date of initial visit
- Reason of the initial visit
- Readmission date
- Reason for readmission
- Number of days between the initial visit and readmission
- Readmission visit recorded must have happened after the initial visit */


SELECT
	ov_initial.patient_id,
	ov_initial.visit_date AS initial_visit_date,
	ov_initial.reason_for_visit AS reason_for_initial_visit,
	ov_readmit.visit_date AS readmission_date,
	ov_readmit.reason_for_visit AS reason_for_readmission,
	DATEDIFF(day, ov_initial.visit_date, ov_readmit.visit_date) AS days_between_initial_and_readmission
FROM [Outpatient Visits] AS ov_initial
INNER JOIN [Outpatient Visits] AS ov_readmit
ON ov_initial.patient_id = ov_readmit.patient_id
WHERE DATEDIFF(day, ov_initial.visit_date, ov_readmit.visit_date) <= 30
AND ov_readmit.visit_date > ov_initial.visit_date


