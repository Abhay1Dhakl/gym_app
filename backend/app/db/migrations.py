from __future__ import annotations

from sqlalchemy import inspect

from app.db.session import engine
from app.models import Base


def ensure_schema() -> None:
    Base.metadata.create_all(bind=engine)

    with engine.begin() as connection:
        inspector = inspect(connection)

        user_columns = {column["name"] for column in inspector.get_columns("users")}
        if "full_name" not in user_columns:
            connection.exec_driver_sql("ALTER TABLE users ADD COLUMN full_name VARCHAR(255)")
        if "organization_id" not in user_columns:
            connection.exec_driver_sql("ALTER TABLE users ADD COLUMN organization_id INTEGER")
        connection.exec_driver_sql("CREATE INDEX IF NOT EXISTS ix_users_organization_id ON users (organization_id)")

        client_columns = {column["name"] for column in inspector.get_columns("client_profiles")}
        if "organization_id" not in client_columns:
            connection.exec_driver_sql("ALTER TABLE client_profiles ADD COLUMN organization_id INTEGER")
        connection.exec_driver_sql(
            "CREATE INDEX IF NOT EXISTS ix_client_profiles_organization_id ON client_profiles (organization_id)"
        )

        training_program_columns = {
            column["name"] for column in inspector.get_columns("training_programs")
        }
        if "start_date" not in training_program_columns:
            connection.exec_driver_sql("ALTER TABLE training_programs ADD COLUMN start_date DATE")
        if "end_date" not in training_program_columns:
            connection.exec_driver_sql("ALTER TABLE training_programs ADD COLUMN end_date DATE")

        invoice_columns = {column["name"] for column in inspector.get_columns("invoices")}
        if "subscription_id" not in invoice_columns:
            connection.exec_driver_sql("ALTER TABLE invoices ADD COLUMN subscription_id INTEGER")
        if "billing_period_start" not in invoice_columns:
            connection.exec_driver_sql("ALTER TABLE invoices ADD COLUMN billing_period_start DATE")
        if "billing_period_end" not in invoice_columns:
            connection.exec_driver_sql("ALTER TABLE invoices ADD COLUMN billing_period_end DATE")
        connection.exec_driver_sql(
            "CREATE INDEX IF NOT EXISTS ix_invoices_subscription_id ON invoices (subscription_id)"
        )
