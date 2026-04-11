from __future__ import annotations

from datetime import date, timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.models.entities import (
    Organization,
    ProgramTemplate,
    ProgramTemplateDay,
    ProgramTemplateExercise,
    TrainingProgram,
    WorkoutDay,
    WorkoutExercise,
)


def build_cycle_dates(start_date: date | None = None, duration_weeks: int = 4) -> tuple[date, date]:
    cycle_start = start_date or date.today()
    cycle_end = cycle_start + timedelta(days=(duration_weeks * 7) - 1)
    return cycle_start, cycle_end


def ensure_template_library(db: Session, organization: Organization) -> None:
    existing = db.scalar(
        select(ProgramTemplate.id).where(ProgramTemplate.organization_id == organization.id)
    )
    if existing is not None:
        return

    for payload in _default_template_blueprints():
        template = ProgramTemplate(
            organization_id=organization.id,
            title=payload["title"],
            phase=payload["phase"],
            goal=payload["goal"],
            summary=payload["summary"],
            duration_weeks=payload["duration_weeks"],
        )
        for day_payload in payload["workout_days"]:
            day = ProgramTemplateDay(
                day_index=day_payload["day_index"],
                title=day_payload["title"],
                focus=day_payload["focus"],
                notes=day_payload.get("notes"),
            )
            for exercise_payload in day_payload["exercises"]:
                day.exercises.append(
                    ProgramTemplateExercise(
                        name=exercise_payload["name"],
                        sets=exercise_payload["sets"],
                        reps=exercise_payload["reps"],
                        rest_seconds=exercise_payload.get("rest_seconds"),
                        target=exercise_payload.get("target"),
                    )
                )
            template.workout_days.append(day)
        db.add(template)

    db.commit()


def clone_program_to_template(
    db: Session,
    organization_id: int,
    program: TrainingProgram,
    title: str,
) -> ProgramTemplate:
    template = ProgramTemplate(
        organization_id=organization_id,
        title=title,
        phase=program.phase,
        goal=program.goal,
        summary=program.summary,
        duration_weeks=max(1, ((program.end_date or date.today()) - (program.start_date or date.today())).days // 7 + 1),
    )
    for day in program.workout_days:
        template_day = ProgramTemplateDay(
            day_index=day.day_index,
            title=day.title,
            focus=day.focus,
            notes=day.notes,
        )
        for exercise in day.exercises:
            template_day.exercises.append(
                ProgramTemplateExercise(
                    name=exercise.name,
                    sets=exercise.sets,
                    reps=exercise.reps,
                    rest_seconds=exercise.rest_seconds,
                    target=exercise.target,
                )
            )
        template.workout_days.append(template_day)
    db.add(template)
    db.commit()
    db.refresh(template)
    return template


def instantiate_program_from_template(
    template: ProgramTemplate,
    client_id: int,
    start_date: date | None = None,
) -> TrainingProgram:
    cycle_start, cycle_end = build_cycle_dates(start_date, template.duration_weeks)
    program = TrainingProgram(
        client_id=client_id,
        title=template.title,
        phase=template.phase,
        goal=template.goal,
        summary=template.summary,
        start_date=cycle_start,
        end_date=cycle_end,
    )
    for day in template.workout_days:
        workout_day = WorkoutDay(
            day_index=day.day_index,
            title=day.title,
            focus=day.focus,
            notes=day.notes,
        )
        for exercise in day.exercises:
            workout_day.exercises.append(
                WorkoutExercise(
                    name=exercise.name,
                    sets=exercise.sets,
                    reps=exercise.reps,
                    rest_seconds=exercise.rest_seconds,
                    target=exercise.target,
                )
            )
        program.workout_days.append(workout_day)
    return program


def get_templates_for_organization(db: Session, organization_id: int) -> list[ProgramTemplate]:
    return db.scalars(
        select(ProgramTemplate)
        .options(
            selectinload(ProgramTemplate.workout_days).selectinload(
                ProgramTemplateDay.exercises
            )
        )
        .where(ProgramTemplate.organization_id == organization_id)
        .order_by(ProgramTemplate.created_at.desc())
    ).all()


def _default_template_blueprints() -> list[dict[str, object]]:
    return [
        {
            "title": "4-Week Strength Foundation",
            "phase": "Foundation",
            "goal": "Build squat, bench, and deadlift confidence with repeatable technical volume.",
            "summary": "A structured four-week cycle for intermediate lifters who need strength momentum without burnout.",
            "duration_weeks": 4,
            "workout_days": [
                {
                    "day_index": 1,
                    "title": "Lower Strength",
                    "focus": "Squat mechanics and posterior chain output",
                    "notes": "Leave one clean rep in reserve on the final work set.",
                    "exercises": [
                        {"name": "Back Squat", "sets": "5", "reps": "4", "rest_seconds": 180, "target": "78-82% 1RM"},
                        {"name": "Romanian Deadlift", "sets": "4", "reps": "6", "rest_seconds": 150, "target": "RPE 7"},
                    ],
                },
                {
                    "day_index": 2,
                    "title": "Upper Strength",
                    "focus": "Bench press stability and upper back density",
                    "notes": "Track bar speed and rest fully between top sets.",
                    "exercises": [
                        {"name": "Bench Press", "sets": "5", "reps": "4", "rest_seconds": 180, "target": "76-80% 1RM"},
                        {"name": "Chest Supported Row", "sets": "4", "reps": "8", "rest_seconds": 120, "target": "Controlled tempo"},
                    ],
                },
            ],
        },
        {
            "title": "4-Week Body Recomp Accelerator",
            "phase": "Body Recomp",
            "goal": "Maintain strength while improving work capacity and weekly compliance.",
            "summary": "Pairs moderate strength work with higher-output accessories for clients cutting body fat.",
            "duration_weeks": 4,
            "workout_days": [
                {
                    "day_index": 1,
                    "title": "Lower Recomp",
                    "focus": "Squat pattern + unilateral volume",
                    "notes": "Keep breathing calm and smooth through rest periods.",
                    "exercises": [
                        {"name": "Front Squat", "sets": "4", "reps": "5", "rest_seconds": 150, "target": "RPE 7"},
                        {"name": "Walking Lunge", "sets": "3", "reps": "12/side", "rest_seconds": 90, "target": "Steady pace"},
                    ],
                },
                {
                    "day_index": 2,
                    "title": "Upper Density",
                    "focus": "Push-pull density and shoulder resilience",
                    "notes": "Limit setup drift and keep transitions fast.",
                    "exercises": [
                        {"name": "Incline Bench Press", "sets": "4", "reps": "6", "rest_seconds": 120, "target": "RPE 7.5"},
                        {"name": "Lat Pulldown", "sets": "4", "reps": "10", "rest_seconds": 75, "target": "Full stretch"},
                    ],
                },
            ],
        },
        {
            "title": "4-Week Hypertrophy Density Block",
            "phase": "Accumulation",
            "goal": "Drive visible hypertrophy with high-quality volume and manageable fatigue.",
            "summary": "Built for physique-focused clients who still need clear progression and recovery guardrails.",
            "duration_weeks": 4,
            "workout_days": [
                {
                    "day_index": 1,
                    "title": "Lower Hypertrophy",
                    "focus": "Quad volume with posterior chain support",
                    "notes": "Control the eccentric and keep reps crisp.",
                    "exercises": [
                        {"name": "Hack Squat", "sets": "4", "reps": "8", "rest_seconds": 120, "target": "2 reps in reserve"},
                        {"name": "Leg Curl", "sets": "4", "reps": "12", "rest_seconds": 75, "target": "Full squeeze"},
                    ],
                },
                {
                    "day_index": 2,
                    "title": "Upper Hypertrophy",
                    "focus": "Chest, delts, and upper back density",
                    "notes": "Keep rest honest and match rep quality set to set.",
                    "exercises": [
                        {"name": "Dumbbell Bench Press", "sets": "4", "reps": "10", "rest_seconds": 90, "target": "Controlled lockout"},
                        {"name": "Cable Row", "sets": "4", "reps": "12", "rest_seconds": 75, "target": "Pause on contraction"},
                    ],
                },
            ],
        },
    ]
