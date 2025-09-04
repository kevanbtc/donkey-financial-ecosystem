#!/usr/bin/env python3
"""
ESG and Incentive Tracking System for Web3 Construction OS
Handles environmental, social, governance tracking and federal/state/local incentive management
"""

from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple, Any
from enum import Enum
from datetime import datetime, date
import json
import asyncio
from decimal import Decimal
import logging

class ESGCategory(Enum):
    ENVIRONMENTAL = "environmental"
    SOCIAL = "social" 
    GOVERNANCE = "governance"

class IncentiveType(Enum):
    FEDERAL_TAX_CREDIT = "federal_tax_credit"
    STATE_TAX_CREDIT = "state_tax_credit"
    LOCAL_REBATE = "local_rebate"
    UTILITY_REBATE = "utility_rebate"
    GRANT = "grant"
    LOW_INTEREST_LOAN = "low_interest_loan"
    PACE_FINANCING = "pace_financing"

@dataclass
class ESGMetric:
    category: ESGCategory
    metric_name: str
    value: float
    unit: str
    timestamp: datetime
    project_id: str
    verification_method: str
    third_party_verified: bool = False
    carbon_offset_tons: Optional[float] = None

@dataclass
class IncentiveOpportunity:
    incentive_id: str
    name: str
    type: IncentiveType
    amount: Decimal
    percentage: Optional[float]
    max_amount: Optional[Decimal]
    state: str
    locality: Optional[str]
    utility_provider: Optional[str]
    eligibility_criteria: List[str]
    application_deadline: Optional[date]
    project_start_deadline: Optional[date]
    project_completion_deadline: Optional[date]
    requires_pre_approval: bool
    stacking_allowed: bool
    clawback_provisions: List[str]

@dataclass
class ESGScore:
    environmental_score: float
    social_score: float
    governance_score: float
    overall_score: float
    peer_percentile: float
    timestamp: datetime
    certification_level: str

class EnvironmentalTracker:
    """Tracks environmental metrics and compliance"""
    
    def __init__(self):
        self.metrics: List[ESGMetric] = []
        self.carbon_credits = {}
        
    async def track_energy_efficiency(self, project_id: str, building_type: str, 
                                    square_footage: float, energy_usage_baseline: float,
                                    energy_usage_actual: float) -> ESGMetric:
        """Track energy efficiency improvements for projects"""
        
        efficiency_improvement = ((energy_usage_baseline - energy_usage_actual) / 
                                energy_usage_baseline) * 100
        
        # Calculate carbon offset based on energy savings
        carbon_offset = (energy_usage_baseline - energy_usage_actual) * 0.0007 * square_footage / 1000
        
        metric = ESGMetric(
            category=ESGCategory.ENVIRONMENTAL,
            metric_name="energy_efficiency_improvement",
            value=efficiency_improvement,
            unit="percentage",
            timestamp=datetime.now(),
            project_id=project_id,
            verification_method="energy_modeling_software",
            third_party_verified=True,
            carbon_offset_tons=carbon_offset
        )
        
        self.metrics.append(metric)
        
        # Track carbon credits
        if carbon_offset > 0:
            self.carbon_credits[project_id] = {
                'tons_offset': carbon_offset,
                'market_value_per_ton': 50.0,  # Current carbon credit market rate
                'total_value': carbon_offset * 50.0,
                'retirement_date': None
            }
            
        return metric
    
    async def track_renewable_energy(self, project_id: str, system_type: str,
                                   capacity_kw: float, annual_production_kwh: float) -> ESGMetric:
        """Track renewable energy installations"""
        
        # Calculate carbon offset from renewable energy
        carbon_offset = annual_production_kwh * 0.0007  # tons CO2/kWh grid average
        
        metric = ESGMetric(
            category=ESGCategory.ENVIRONMENTAL,
            metric_name=f"renewable_energy_{system_type}",
            value=capacity_kw,
            unit="kW_capacity",
            timestamp=datetime.now(),
            project_id=project_id,
            verification_method="utility_interconnection_agreement",
            third_party_verified=True,
            carbon_offset_tons=carbon_offset
        )
        
        self.metrics.append(metric)
        return metric
    
    async def track_water_efficiency(self, project_id: str, baseline_usage: float,
                                   improved_usage: float) -> ESGMetric:
        """Track water efficiency improvements"""
        
        water_savings = baseline_usage - improved_usage
        savings_percentage = (water_savings / baseline_usage) * 100
        
        metric = ESGMetric(
            category=ESGCategory.ENVIRONMENTAL,
            metric_name="water_efficiency_improvement",
            value=savings_percentage,
            unit="percentage",
            timestamp=datetime.now(),
            project_id=project_id,
            verification_method="water_meter_readings",
            third_party_verified=False
        )
        
        self.metrics.append(metric)
        return metric

    async def track_waste_diversion(self, project_id: str, total_waste: float,
                                  diverted_waste: float) -> ESGMetric:
        """Track construction waste diversion from landfills"""
        
        diversion_rate = (diverted_waste / total_waste) * 100
        
        metric = ESGMetric(
            category=ESGCategory.ENVIRONMENTAL,
            metric_name="waste_diversion_rate",
            value=diversion_rate,
            unit="percentage",
            timestamp=datetime.now(),
            project_id=project_id,
            verification_method="waste_management_receipts",
            third_party_verified=True
        )
        
        self.metrics.append(metric)
        return metric

class SocialImpactTracker:
    """Tracks social impact metrics"""
    
    def __init__(self):
        self.metrics: List[ESGMetric] = []
        
    async def track_local_hiring(self, project_id: str, total_workers: int,
                               local_workers: int, zip_code_radius: int = 25) -> ESGMetric:
        """Track local hiring percentages"""
        
        local_hire_rate = (local_workers / total_workers) * 100
        
        metric = ESGMetric(
            category=ESGCategory.SOCIAL,
            metric_name="local_hire_rate",
            value=local_hire_rate,
            unit="percentage",
            timestamp=datetime.now(),
            project_id=project_id,
            verification_method="payroll_address_verification"
        )
        
        self.metrics.append(metric)
        return metric
    
    async def track_diversity_hiring(self, project_id: str, total_workers: int,
                                   minority_workers: int, women_workers: int,
                                   veteran_workers: int) -> List[ESGMetric]:
        """Track diversity in hiring"""
        
        metrics = []
        
        # Minority hiring rate
        minority_rate = (minority_workers / total_workers) * 100
        metrics.append(ESGMetric(
            category=ESGCategory.SOCIAL,
            metric_name="minority_hire_rate",
            value=minority_rate,
            unit="percentage",
            timestamp=datetime.now(),
            project_id=project_id,
            verification_method="self_identification_forms"
        ))
        
        # Women hiring rate
        women_rate = (women_workers / total_workers) * 100
        metrics.append(ESGMetric(
            category=ESGCategory.SOCIAL,
            metric_name="women_hire_rate", 
            value=women_rate,
            unit="percentage",
            timestamp=datetime.now(),
            project_id=project_id,
            verification_method="self_identification_forms"
        ))
        
        # Veteran hiring rate
        veteran_rate = (veteran_workers / total_workers) * 100
        metrics.append(ESGMetric(
            category=ESGCategory.SOCIAL,
            metric_name="veteran_hire_rate",
            value=veteran_rate,
            unit="percentage", 
            timestamp=datetime.now(),
            project_id=project_id,
            verification_method="dd214_verification"
        ))
        
        self.metrics.extend(metrics)
        return metrics
    
    async def track_apprenticeship_programs(self, project_id: str, total_hours: float,
                                          apprentice_hours: float) -> ESGMetric:
        """Track apprenticeship program participation"""
        
        apprentice_rate = (apprentice_hours / total_hours) * 100
        
        metric = ESGMetric(
            category=ESGCategory.SOCIAL,
            metric_name="apprenticeship_rate",
            value=apprentice_rate,
            unit="percentage",
            timestamp=datetime.now(),
            project_id=project_id,
            verification_method="union_training_records"
        )
        
        self.metrics.append(metric)
        return metric

    async def track_safety_metrics(self, project_id: str, total_hours: float,
                                 incidents: int, near_misses: int) -> List[ESGMetric]:
        """Track workplace safety metrics"""
        
        metrics = []
        
        # Incident rate per 200,000 hours (OSHA standard)
        incident_rate = (incidents / total_hours) * 200000
        metrics.append(ESGMetric(
            category=ESGCategory.SOCIAL,
            metric_name="osha_incident_rate",
            value=incident_rate,
            unit="incidents_per_200k_hours",
            timestamp=datetime.now(),
            project_id=project_id,
            verification_method="osha_logs"
        ))
        
        # Near miss reporting rate
        near_miss_rate = (near_misses / total_hours) * 200000
        metrics.append(ESGMetric(
            category=ESGCategory.SOCIAL,
            metric_name="near_miss_rate",
            value=near_miss_rate,
            unit="near_misses_per_200k_hours",
            timestamp=datetime.now(),
            project_id=project_id,
            verification_method="safety_reporting_system"
        ))
        
        self.metrics.extend(metrics)
        return metrics

class GovernanceTracker:
    """Tracks governance and compliance metrics"""
    
    def __init__(self):
        self.metrics: List[ESGMetric] = []
        
    async def track_compliance_scores(self, project_id: str, state: str,
                                    permit_compliance: float, safety_compliance: float,
                                    environmental_compliance: float) -> List[ESGMetric]:
        """Track various compliance scores"""
        
        metrics = []
        
        compliance_types = [
            ("permit_compliance", permit_compliance),
            ("safety_compliance", safety_compliance), 
            ("environmental_compliance", environmental_compliance)
        ]
        
        for compliance_type, score in compliance_types:
            metric = ESGMetric(
                category=ESGCategory.GOVERNANCE,
                metric_name=compliance_type,
                value=score,
                unit="percentage",
                timestamp=datetime.now(),
                project_id=project_id,
                verification_method="regulatory_audit"
            )
            metrics.append(metric)
        
        self.metrics.extend(metrics)
        return metrics
    
    async def track_certification_status(self, project_id: str, certifications: List[str]) -> ESGMetric:
        """Track project certifications (LEED, Energy Star, etc.)"""
        
        certification_count = len(certifications)
        
        metric = ESGMetric(
            category=ESGCategory.GOVERNANCE,
            metric_name="certification_count",
            value=certification_count,
            unit="count",
            timestamp=datetime.now(),
            project_id=project_id,
            verification_method="certification_body_verification"
        )
        
        self.metrics.append(metric)
        return metric

class IncentiveCalculationEngine:
    """Calculates available incentives based on project characteristics"""
    
    def __init__(self):
        self.federal_incentives = self._load_federal_incentives()
        self.state_incentives = self._load_state_incentives()
        self.local_incentives = self._load_local_incentives()
        self.utility_incentives = self._load_utility_incentives()
        
    def _load_federal_incentives(self) -> List[IncentiveOpportunity]:
        """Load federal tax credits and incentives"""
        return [
            IncentiveOpportunity(
                incentive_id="ITC_SOLAR_2024",
                name="Solar Investment Tax Credit", 
                type=IncentiveType.FEDERAL_TAX_CREDIT,
                amount=Decimal('0'),
                percentage=30.0,
                max_amount=None,
                state="ALL",
                locality=None,
                utility_provider=None,
                eligibility_criteria=[
                    "Solar PV system installation",
                    "System must be placed in service by Dec 31, 2032",
                    "System must meet IRS guidelines"
                ],
                application_deadline=None,
                project_start_deadline=date(2032, 12, 31),
                project_completion_deadline=date(2032, 12, 31),
                requires_pre_approval=False,
                stacking_allowed=True,
                clawback_provisions=["System must remain in service for 5 years"]
            ),
            IncentiveOpportunity(
                incentive_id="PTC_WIND_2024",
                name="Wind Production Tax Credit",
                type=IncentiveType.FEDERAL_TAX_CREDIT,
                amount=Decimal('28'),
                percentage=None,
                max_amount=None,
                state="ALL",
                locality=None,
                utility_provider=None,
                eligibility_criteria=[
                    "Wind energy facility",
                    "Construction begins before Jan 1, 2025"
                ],
                application_deadline=None,
                project_start_deadline=date(2024, 12, 31),
                project_completion_deadline=None,
                requires_pre_approval=False,
                stacking_allowed=True,
                clawback_provisions=[]
            ),
            IncentiveOpportunity(
                incentive_id="179D_DEDUCTION_2024",
                name="179D Energy Efficient Commercial Buildings Deduction",
                type=IncentiveType.FEDERAL_TAX_CREDIT,
                amount=Decimal('5.36'),
                percentage=None,
                max_amount=None,
                state="ALL",
                locality=None,
                utility_provider=None,
                eligibility_criteria=[
                    "Commercial building",
                    "50%+ energy reduction vs ASHRAE standard",
                    "Prevailing wage requirements met"
                ],
                application_deadline=None,
                project_start_deadline=None,
                project_completion_deadline=None,
                requires_pre_approval=False,
                stacking_allowed=True,
                clawback_provisions=[]
            ),
            IncentiveOpportunity(
                incentive_id="45L_CREDIT_2024", 
                name="45L New Energy Efficient Home Credit",
                type=IncentiveType.FEDERAL_TAX_CREDIT,
                amount=Decimal('5000'),
                percentage=None,
                max_amount=None,
                state="ALL",
                locality=None,
                utility_provider=None,
                eligibility_criteria=[
                    "Qualified new home",
                    "Energy Star or equivalent certification",
                    "Meets prevailing wage requirements"
                ],
                application_deadline=None,
                project_start_deadline=None,
                project_completion_deadline=date(2032, 12, 31),
                requires_pre_approval=False,
                stacking_allowed=True,
                clawback_provisions=[]
            )
        ]
    
    def _load_state_incentives(self) -> Dict[str, List[IncentiveOpportunity]]:
        """Load state-specific incentives"""
        return {
            "FL": [
                IncentiveOpportunity(
                    incentive_id="FL_SOLAR_REBATE_2024",
                    name="Florida Solar Rebate Program",
                    type=IncentiveType.STATE_TAX_CREDIT,
                    amount=Decimal('0'),
                    percentage=None,
                    max_amount=Decimal('20000'),
                    state="FL",
                    locality=None,
                    utility_provider=None,
                    eligibility_criteria=[
                        "Florida resident",
                        "Solar PV system", 
                        "System size 2kW minimum"
                    ],
                    application_deadline=date(2024, 12, 31),
                    project_start_deadline=None,
                    project_completion_deadline=None,
                    requires_pre_approval=True,
                    stacking_allowed=True,
                    clawback_provisions=[]
                ),
                IncentiveOpportunity(
                    incentive_id="FL_PACE_2024",
                    name="Florida PACE Financing",
                    type=IncentiveType.PACE_FINANCING,
                    amount=Decimal('0'),
                    percentage=None,
                    max_amount=Decimal('1000000'),
                    state="FL",
                    locality=None,
                    utility_provider=None,
                    eligibility_criteria=[
                        "Commercial or industrial property",
                        "Energy efficiency or renewable energy project"
                    ],
                    application_deadline=None,
                    project_start_deadline=None,
                    project_completion_deadline=None,
                    requires_pre_approval=True,
                    stacking_allowed=True,
                    clawback_provisions=[]
                )
            ],
            "TX": [
                IncentiveOpportunity(
                    incentive_id="TX_SOLAR_EXEMPTION_2024",
                    name="Texas Solar Property Tax Exemption",
                    type=IncentiveType.STATE_TAX_CREDIT,
                    amount=Decimal('0'),
                    percentage=100.0,
                    max_amount=None,
                    state="TX",
                    locality=None,
                    utility_provider=None,
                    eligibility_criteria=[
                        "Solar energy device",
                        "Installed on or in connection with dwelling"
                    ],
                    application_deadline=None,
                    project_start_deadline=None,
                    project_completion_deadline=None,
                    requires_pre_approval=False,
                    stacking_allowed=True,
                    clawback_provisions=[]
                )
            ],
            "LA": [
                IncentiveOpportunity(
                    incentive_id="LA_SOLAR_TAX_CREDIT_2024",
                    name="Louisiana Solar Tax Credit",
                    type=IncentiveType.STATE_TAX_CREDIT,
                    amount=Decimal('0'),
                    percentage=25.0,
                    max_amount=Decimal('12500'),
                    state="LA",
                    locality=None,
                    utility_provider=None,
                    eligibility_criteria=[
                        "Louisiana resident",
                        "Solar energy system for residence"
                    ],
                    application_deadline=None,
                    project_start_deadline=None,
                    project_completion_deadline=date(2025, 12, 31),
                    requires_pre_approval=False,
                    stacking_allowed=True,
                    clawback_provisions=[]
                )
            ],
            "NY": [
                IncentiveOpportunity(
                    incentive_id="NY_SOLAR_TAX_CREDIT_2024",
                    name="New York State Solar Tax Credit",
                    type=IncentiveType.STATE_TAX_CREDIT,
                    amount=Decimal('0'),
                    percentage=25.0,
                    max_amount=Decimal('5000'),
                    state="NY",
                    locality=None,
                    utility_provider=None,
                    eligibility_criteria=[
                        "New York State resident",
                        "Solar electric generating equipment"
                    ],
                    application_deadline=None,
                    project_start_deadline=None,
                    project_completion_deadline=date(2025, 12, 31),
                    requires_pre_approval=False,
                    stacking_allowed=True,
                    clawback_provisions=[]
                )
            ]
        }
    
    def _load_local_incentives(self) -> Dict[str, List[IncentiveOpportunity]]:
        """Load local utility and municipal incentives"""
        return {
            "miami_dade_fl": [
                IncentiveOpportunity(
                    incentive_id="MIAMI_SOLAR_REBATE_2024",
                    name="Miami-Dade Solar Rebate",
                    type=IncentiveType.LOCAL_REBATE,
                    amount=Decimal('1000'),
                    percentage=None,
                    max_amount=Decimal('1000'),
                    state="FL",
                    locality="Miami-Dade",
                    utility_provider=None,
                    eligibility_criteria=[
                        "Miami-Dade County resident",
                        "Solar PV installation"
                    ],
                    application_deadline=date(2024, 12, 31),
                    project_start_deadline=None,
                    project_completion_deadline=None,
                    requires_pre_approval=True,
                    stacking_allowed=True,
                    clawback_provisions=[]
                )
            ]
        }
    
    def _load_utility_incentives(self) -> Dict[str, List[IncentiveOpportunity]]:
        """Load utility-specific incentives"""
        return {
            "fpl": [
                IncentiveOpportunity(
                    incentive_id="FPL_SOLAR_REBATE_2024",
                    name="FPL SolarTogether Program",
                    type=IncentiveType.UTILITY_REBATE,
                    amount=Decimal('0.03'),
                    percentage=None,
                    max_amount=None,
                    state="FL",
                    locality=None,
                    utility_provider="Florida Power & Light",
                    eligibility_criteria=[
                        "FPL customer",
                        "Community solar subscription"
                    ],
                    application_deadline=None,
                    project_start_deadline=None,
                    project_completion_deadline=None,
                    requires_pre_approval=True,
                    stacking_allowed=True,
                    clawback_provisions=[]
                )
            ]
        }
    
    async def calculate_available_incentives(self, project_data: Dict[str, Any]) -> List[IncentiveOpportunity]:
        """Calculate all available incentives for a project"""
        
        available_incentives = []
        
        # Check federal incentives
        for incentive in self.federal_incentives:
            if await self._check_eligibility(incentive, project_data):
                available_incentives.append(incentive)
        
        # Check state incentives
        state = project_data.get('state')
        if state in self.state_incentives:
            for incentive in self.state_incentives[state]:
                if await self._check_eligibility(incentive, project_data):
                    available_incentives.append(incentive)
        
        # Check local incentives
        locality_key = f"{project_data.get('city', '').lower().replace(' ', '_')}_{state.lower()}"
        if locality_key in self.local_incentives:
            for incentive in self.local_incentives[locality_key]:
                if await self._check_eligibility(incentive, project_data):
                    available_incentives.append(incentive)
        
        # Check utility incentives
        utility = project_data.get('utility_provider', '').lower().replace(' ', '').replace('&', '')
        if utility in self.utility_incentives:
            for incentive in self.utility_incentives[utility]:
                if await self._check_eligibility(incentive, project_data):
                    available_incentives.append(incentive)
        
        return available_incentives
    
    async def _check_eligibility(self, incentive: IncentiveOpportunity, 
                               project_data: Dict[str, Any]) -> bool:
        """Check if project meets incentive eligibility criteria"""
        
        project_type = project_data.get('project_type', '').lower()
        
        # Basic project type matching
        criteria_met = 0
        for criterion in incentive.eligibility_criteria:
            criterion_lower = criterion.lower()
            
            if 'solar' in criterion_lower and 'solar' in project_type:
                criteria_met += 1
            elif 'wind' in criterion_lower and 'wind' in project_type:
                criteria_met += 1
            elif 'energy efficiency' in criterion_lower and 'efficiency' in project_type:
                criteria_met += 1
            elif 'commercial' in criterion_lower and project_data.get('building_type') == 'commercial':
                criteria_met += 1
            elif 'residential' in criterion_lower and project_data.get('building_type') == 'residential':
                criteria_met += 1
        
        # Check date eligibility
        current_date = date.today()
        if incentive.application_deadline and current_date > incentive.application_deadline:
            return False
        if incentive.project_completion_deadline and current_date > incentive.project_completion_deadline:
            return False
            
        # Return true if at least one criterion is met
        return criteria_met > 0
    
    async def calculate_incentive_value(self, incentive: IncentiveOpportunity,
                                      project_cost: Decimal, project_size: Optional[float] = None) -> Decimal:
        """Calculate the monetary value of an incentive"""
        
        if incentive.percentage:
            value = project_cost * Decimal(str(incentive.percentage / 100))
            if incentive.max_amount:
                value = min(value, incentive.max_amount)
        elif project_size and incentive.amount:
            # Per unit incentives (e.g., $/kW, $/sqft)
            value = Decimal(str(project_size)) * incentive.amount
        else:
            value = incentive.amount or Decimal('0')
        
        return value

class ESGScoringEngine:
    """Calculates comprehensive ESG scores for projects and contractors"""
    
    def __init__(self):
        self.environmental_tracker = EnvironmentalTracker()
        self.social_tracker = SocialImpactTracker() 
        self.governance_tracker = GovernanceTracker()
        
    async def calculate_esg_score(self, project_id: str) -> ESGScore:
        """Calculate comprehensive ESG score for a project"""
        
        # Get all metrics for the project
        env_metrics = [m for m in self.environmental_tracker.metrics if m.project_id == project_id]
        social_metrics = [m for m in self.social_tracker.metrics if m.project_id == project_id]
        gov_metrics = [m for m in self.governance_tracker.metrics if m.project_id == project_id]
        
        # Calculate category scores
        env_score = await self._calculate_environmental_score(env_metrics)
        social_score = await self._calculate_social_score(social_metrics)
        gov_score = await self._calculate_governance_score(gov_metrics)
        
        # Calculate overall score (weighted average)
        overall_score = (env_score * 0.4 + social_score * 0.35 + gov_score * 0.25)
        
        # Determine peer percentile (mock calculation)
        peer_percentile = min(95, max(5, overall_score + (overall_score * 0.1)))
        
        # Determine certification level
        if overall_score >= 90:
            cert_level = "Platinum"
        elif overall_score >= 80:
            cert_level = "Gold"
        elif overall_score >= 70:
            cert_level = "Silver" 
        elif overall_score >= 60:
            cert_level = "Bronze"
        else:
            cert_level = "Standard"
        
        return ESGScore(
            environmental_score=env_score,
            social_score=social_score,
            governance_score=gov_score,
            overall_score=overall_score,
            peer_percentile=peer_percentile,
            timestamp=datetime.now(),
            certification_level=cert_level
        )
    
    async def _calculate_environmental_score(self, metrics: List[ESGMetric]) -> float:
        """Calculate environmental component score"""
        if not metrics:
            return 50.0  # Baseline score
        
        score = 50.0  # Start with baseline
        
        for metric in metrics:
            if metric.metric_name == "energy_efficiency_improvement":
                # Higher efficiency improvement = higher score
                score += min(20, metric.value * 0.5)
            elif "renewable_energy" in metric.metric_name:
                # Renewable energy installations boost score
                score += 15
            elif metric.metric_name == "water_efficiency_improvement":
                score += min(10, metric.value * 0.3)
            elif metric.metric_name == "waste_diversion_rate":
                score += min(15, metric.value * 0.2)
            
            # Third-party verification bonus
            if metric.third_party_verified:
                score += 2
        
        return min(100.0, score)
    
    async def _calculate_social_score(self, metrics: List[ESGMetric]) -> float:
        """Calculate social component score"""
        if not metrics:
            return 50.0
        
        score = 50.0
        
        for metric in metrics:
            if metric.metric_name == "local_hire_rate":
                score += min(15, metric.value * 0.3)
            elif "hire_rate" in metric.metric_name:
                # Diversity hiring metrics
                score += min(10, metric.value * 0.2)
            elif metric.metric_name == "apprenticeship_rate":
                score += min(10, metric.value * 0.4)
            elif metric.metric_name == "osha_incident_rate":
                # Lower incident rate = higher score
                if metric.value < 2.0:  # Industry average
                    score += 15
                elif metric.value < 4.0:
                    score += 5
        
        return min(100.0, score)
    
    async def _calculate_governance_score(self, metrics: List[ESGMetric]) -> float:
        """Calculate governance component score"""
        if not metrics:
            return 50.0
        
        score = 50.0
        
        for metric in metrics:
            if "compliance" in metric.metric_name:
                # High compliance scores boost governance score
                score += min(15, (metric.value / 100) * 15)
            elif metric.metric_name == "certification_count":
                score += min(10, metric.value * 3)
        
        return min(100.0, score)

class ESGIncentiveIntegrationEngine:
    """Main engine that integrates ESG tracking with incentive calculations"""
    
    def __init__(self):
        self.esg_scoring = ESGScoringEngine()
        self.incentive_calc = IncentiveCalculationEngine()
        
    async def process_project_esg_incentives(self, project_data: Dict[str, Any]) -> Dict[str, Any]:
        """Process complete ESG tracking and incentive calculation for a project"""
        
        project_id = project_data.get('project_id')
        
        # Track ESG metrics based on project type
        await self._track_project_metrics(project_id, project_data)
        
        # Calculate ESG score
        esg_score = await self.esg_scoring.calculate_esg_score(project_id)
        
        # Find available incentives
        available_incentives = await self.incentive_calc.calculate_available_incentives(project_data)
        
        # Calculate incentive values
        project_cost = Decimal(str(project_data.get('project_cost', 0)))
        project_size = project_data.get('project_size')
        
        incentive_summary = []
        total_incentive_value = Decimal('0')
        
        for incentive in available_incentives:
            value = await self.incentive_calc.calculate_incentive_value(
                incentive, project_cost, project_size
            )
            
            incentive_summary.append({
                'name': incentive.name,
                'type': incentive.type.value,
                'value': float(value),
                'requires_pre_approval': incentive.requires_pre_approval,
                'application_deadline': incentive.application_deadline.isoformat() if incentive.application_deadline else None
            })
            
            total_incentive_value += value
        
        return {
            'project_id': project_id,
            'esg_score': {
                'environmental': esg_score.environmental_score,
                'social': esg_score.social_score,
                'governance': esg_score.governance_score,
                'overall': esg_score.overall_score,
                'certification_level': esg_score.certification_level,
                'peer_percentile': esg_score.peer_percentile
            },
            'available_incentives': incentive_summary,
            'total_incentive_value': float(total_incentive_value),
            'net_project_cost': float(project_cost - total_incentive_value),
            'roi_improvement': float((total_incentive_value / project_cost) * 100) if project_cost > 0 else 0
        }
    
    async def _track_project_metrics(self, project_id: str, project_data: Dict[str, Any]):
        """Track relevant ESG metrics based on project characteristics"""
        
        project_type = project_data.get('project_type', '').lower()
        
        if 'solar' in project_type:
            await self.esg_scoring.environmental_tracker.track_renewable_energy(
                project_id, 
                "solar_pv",
                project_data.get('system_capacity_kw', 10.0),
                project_data.get('annual_production_kwh', 15000)
            )
        
        if 'energy efficiency' in project_type:
            await self.esg_scoring.environmental_tracker.track_energy_efficiency(
                project_id,
                project_data.get('building_type', 'commercial'),
                project_data.get('square_footage', 5000),
                project_data.get('baseline_energy_usage', 100000),
                project_data.get('projected_energy_usage', 70000)
            )
        
        # Track social metrics for all projects
        await self.esg_scoring.social_tracker.track_local_hiring(
            project_id,
            project_data.get('total_workers', 10),
            project_data.get('local_workers', 8)
        )
        
        await self.esg_scoring.social_tracker.track_safety_metrics(
            project_id,
            project_data.get('total_hours', 2000),
            project_data.get('incidents', 0),
            project_data.get('near_misses', 2)
        )

# Example usage and testing
async def main():
    """Example usage of the ESG and Incentive Tracking System"""
    
    print("🌱 ESG and Incentive Tracking System Demo")
    print("=" * 50)
    
    # Initialize the integration engine
    esg_engine = ESGIncentiveIntegrationEngine()
    
    # Example storm restoration project with solar installation
    storm_project = {
        'project_id': 'STORM_2024_MIAMI_001',
        'project_type': 'storm restoration with solar installation',
        'building_type': 'commercial',
        'project_cost': 250000,
        'system_capacity_kw': 50.0,
        'annual_production_kwh': 75000,
        'square_footage': 10000,
        'baseline_energy_usage': 120000,
        'projected_energy_usage': 80000,
        'state': 'FL',
        'city': 'Miami',
        'utility_provider': 'Florida Power & Light',
        'total_workers': 15,
        'local_workers': 12,
        'total_hours': 3000,
        'incidents': 0,
        'near_misses': 1,
        'project_size': 50.0  # kW for solar
    }
    
    # Process ESG metrics and incentives
    result = await esg_engine.process_project_esg_incentives(storm_project)
    
    print(f"📊 Project: {result['project_id']}")
    print(f"💰 Total Project Cost: ${storm_project['project_cost']:,}")
    print(f"🎯 Net Cost After Incentives: ${result['net_project_cost']:,.2f}")
    print(f"💵 Total Incentive Value: ${result['total_incentive_value']:,.2f}")
    print(f"📈 ROI Improvement: {result['roi_improvement']:.1f}%")
    print()
    
    print("🌟 ESG Scores:")
    esg = result['esg_score']
    print(f"  Environmental: {esg['environmental']:.1f}/100")
    print(f"  Social: {esg['social']:.1f}/100") 
    print(f"  Governance: {esg['governance']:.1f}/100")
    print(f"  Overall: {esg['overall']:.1f}/100")
    print(f"  Certification Level: {esg['certification_level']}")
    print(f"  Peer Percentile: {esg['peer_percentile']:.1f}%")
    print()
    
    print("💡 Available Incentives:")
    for incentive in result['available_incentives']:
        print(f"  • {incentive['name']}: ${incentive['value']:,.2f}")
        if incentive['requires_pre_approval']:
            print(f"    ⚠️  Requires pre-approval")
        if incentive['application_deadline']:
            print(f"    📅 Application deadline: {incentive['application_deadline']}")
    
    # Example residential project
    print("\n" + "=" * 50)
    print("🏠 Residential Solar Project Example")
    
    residential_project = {
        'project_id': 'RES_2024_TAMPA_001',
        'project_type': 'residential solar installation',
        'building_type': 'residential',
        'project_cost': 25000,
        'system_capacity_kw': 8.0,
        'annual_production_kwh': 12000,
        'state': 'FL',
        'city': 'Tampa',
        'utility_provider': 'TECO',
        'total_workers': 4,
        'local_workers': 4,
        'total_hours': 200,
        'incidents': 0,
        'near_misses': 0,
        'project_size': 8.0
    }
    
    residential_result = await esg_engine.process_project_esg_incentives(residential_project)
    
    print(f"📊 Project: {residential_result['project_id']}")
    print(f"💰 Total Project Cost: ${residential_project['project_cost']:,}")
    print(f"💵 Total Incentive Value: ${residential_result['total_incentive_value']:,.2f}")
    print(f"📈 ROI Improvement: {residential_result['roi_improvement']:.1f}%")
    
    print("\n✅ ESG and Incentive Integration System Ready!")

if __name__ == "__main__":
    asyncio.run(main())