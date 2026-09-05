CREATE DATABASE fintech_credit_risk;
USE fintech_credit_risk;
SELECT DATABASE();
CREATE TABLE portfolio_impact (
    threshold DECIMAL(4,2),
    borrowers INT,
    portfolio_flagged_pct DECIMAL(6,2),
    bad_loans_captured INT,
    bad_loan_capture_pct DECIMAL(6,2),
    good_loans_flagged INT,
    bad_loans_missed INT,
    flagged_group_bad_rate DECIMAL(6,2)
);
SHOW TABLES;
SELECT *
FROM portfolio_impact;
SELECT
    threshold,
    borrowers,
    portfolio_flagged_pct,
    bad_loans_captured,
    bad_loan_capture_pct,
    bad_loans_missed
FROM portfolio_impact
ORDER BY threshold;

SELECT
    threshold,
    borrowers,
    portfolio_flagged_pct,
    bad_loan_capture_pct,
    bad_loans_missed,

    LAG(borrowers) OVER (ORDER BY threshold) AS previous_borrowers,

    borrowers - LAG(borrowers) OVER (ORDER BY threshold)
        AS change_in_borrowers,

    bad_loan_capture_pct -
        LAG(bad_loan_capture_pct) OVER (ORDER BY threshold)
        AS change_in_capture_pct

FROM portfolio_impact
ORDER BY threshold;

SELECT
    threshold,
    borrowers,
    portfolio_flagged_pct,
    bad_loan_capture_pct,

    LAG(borrowers) OVER (ORDER BY threshold) AS previous_borrowers,

    LAG(bad_loan_capture_pct) OVER (ORDER BY threshold)
        AS previous_capture_pct,

    ROUND(
        (LAG(borrowers) OVER (ORDER BY threshold) - borrowers)
        /
        NULLIF(
            LAG(bad_loan_capture_pct) OVER (ORDER BY threshold)
            - bad_loan_capture_pct,
            0
        ),
        0
    ) AS borrowers_reduced_per_capture_point

FROM portfolio_impact
ORDER BY threshold

USE fintech_credit_risk;

SELECT *
FROM risk_segmentation;

-- Analysis 4: Risk Band Performance
SELECT
    risk_band,
    borrower_count,
    actual_bad_loans,
    ROUND(actual_bad_rate, 2) AS actual_bad_rate,
    ROUND(average_predicted_probability, 2) AS avg_predicted_probability
FROM risk_segmentation
ORDER BY
    CASE risk_band
        WHEN 'Low Risk' THEN 1
        WHEN 'Moderate Risk' THEN 2
        WHEN 'High Risk' THEN 3
        WHEN 'Very High Risk' THEN 4
    END;
    
    -- Analysis 5: Model Calibration Gap
SELECT
    risk_band,
    borrower_count,
    ROUND(average_predicted_probability, 2) AS predicted_bad_rate,
    ROUND(actual_bad_rate, 2) AS actual_bad_rate,

    ROUND(
        average_predicted_probability - actual_bad_rate,
        2
    ) AS prediction_gap

FROM risk_segmentation

ORDER BY
    CASE risk_band
        WHEN 'Low Risk' THEN 1
        WHEN 'Moderate Risk' THEN 2
        WHEN 'High Risk' THEN 3
        WHEN 'Very High Risk' THEN 4
    END;
    -- Analysis 6: Threshold Decision Trade-off
SELECT
    threshold,
    borrowers,
    ROUND(portfolio_flagged_pct, 2) AS portfolio_flagged_pct,
    bad_loans_captured,
    ROUND(bad_loan_capture_pct, 2) AS bad_loan_capture_pct,
    bad_loans_missed,

    ROUND(
        100 - portfolio_flagged_pct,
        2
    ) AS portfolio_excluded_pct,

    ROUND(
        100 - bad_loan_capture_pct,
        2
    ) AS bad_loans_missed_pct

FROM portfolio_impact

ORDER BY threshold;

-- Analysis 7: Risk Capture Efficiency

SELECT
    threshold,
    ROUND(portfolio_flagged_pct, 2) AS portfolio_flagged_pct,
    ROUND(bad_loan_capture_pct, 2) AS bad_loan_capture_pct,

    ROUND(
        bad_loan_capture_pct / portfolio_flagged_pct,
        2
    ) AS capture_efficiency,

    bad_loans_captured,
    bad_loans_missed

FROM portfolio_impact

ORDER BY capture_efficiency DESC;

-- Analysis 8: Good Borrower Impact

SELECT
    threshold,
    borrowers,
    bad_loans_captured,
    good_loans_flagged,

    ROUND(
        good_loans_flagged * 100.0 / borrowers,
        2
    ) AS good_borrower_flagged_pct,

    ROUND(
        good_loans_flagged * 100.0 /
        (good_loans_flagged + bad_loans_captured),
        2
    ) AS false_positive_rate

FROM portfolio_impact

ORDER BY threshold;
-- Analysis 8: Good Borrower Impact

SELECT
    p.threshold,
    p.borrowers AS flagged_borrowers,
    p.bad_loans_captured,
    p.good_loans_flagged,

    ROUND(
        p.good_loans_flagged * 100.0 /
        (SELECT SUM(borrower_count) FROM risk_segmentation),
        2
    ) AS good_borrowers_flagged_pct,

    ROUND(
        p.good_loans_flagged * 100.0 /
        p.borrowers,
        2
    ) AS false_positive_rate

FROM portfolio_impact p

ORDER BY p.threshold;
-- Analysis 9: Recommended Decision Threshold
-- Business constraint: maintain at least 90% bad-loan capture

SELECT
    threshold,
    borrowers AS flagged_borrowers,
    ROUND(portfolio_flagged_pct, 2) AS portfolio_flagged_pct,
    bad_loans_captured,
    ROUND(bad_loan_capture_pct, 2) AS bad_loan_capture_pct,
    bad_loans_missed,

    CASE
        WHEN bad_loan_capture_pct >= 90
        THEN 'Meets 90% capture target'
        ELSE 'Below 90% capture target'
    END AS decision_status

FROM portfolio_impact

ORDER BY threshold;
-- Analysis 9B: Highest Threshold Meeting 90% Capture Target

SELECT
    MAX(threshold) AS recommended_threshold

FROM portfolio_impact

WHERE bad_loan_capture_pct >= 90;

SELECT
    threshold,
    borrowers AS flagged_borrowers,
    ROUND(portfolio_flagged_pct, 2) AS portfolio_flagged_pct,
    bad_loans_captured,
    ROUND(bad_loan_capture_pct, 2) AS bad_loan_capture_pct,
    bad_loans_missed,
    CASE
        WHEN bad_loan_capture_pct >= 90
        THEN 'Recommended'
        ELSE 'Below Target'
    END AS decision
FROM portfolio_impact
ORDER BY threshold;