from __future__ import annotations

from calendar import monthrange
from datetime import date, timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.models.entities import ClientProfile, ClientSubscription, Invoice, InvoiceStatus, SubscriptionStatus


def add_months(value: date, months: int = 1) -> date:
    month_index = value.month - 1 + months
    year = value.year + month_index // 12
    month = month_index % 12 + 1
    day = min(value.day, monthrange(year, month)[1])
    return date(year, month, day)


def sync_subscriptions(db: Session, organization_id: int | None = None, today: date | None = None) -> None:
    current_day = today or date.today()
    statement = (
        select(ClientSubscription)
        .join(ClientProfile, ClientSubscription.client_id == ClientProfile.id)
        .options(selectinload(ClientSubscription.invoices), selectinload(ClientSubscription.client))
    )
    if organization_id is not None:
        statement = statement.where(ClientProfile.organization_id == organization_id)

    subscriptions = db.scalars(statement).all()

    changed = False
    for subscription in subscriptions:
        changed |= _sync_subscription(subscription, current_day)

    if changed:
        db.commit()


def _sync_subscription(subscription: ClientSubscription, today: date) -> bool:
    changed = False

    for invoice in subscription.invoices:
        if invoice.status == InvoiceStatus.PENDING and invoice.due_date < today:
            invoice.status = InvoiceStatus.OVERDUE
            changed = True

    if subscription.status in {SubscriptionStatus.ACTIVE, SubscriptionStatus.TRIALING}:
        while subscription.next_invoice_date <= today:
            period_start = subscription.next_invoice_date
            period_end = add_months(period_start, 1) - timedelta(days=1)
            already_exists = any(
                invoice.subscription_id == subscription.id
                and invoice.billing_period_start == period_start
                for invoice in subscription.invoices
            )
            if not already_exists:
                subscription.invoices.append(
                    Invoice(
                        client_id=subscription.client_id,
                        subscription_id=subscription.id,
                        title=f"{subscription.plan_name} - {period_start.strftime('%B %Y')}",
                        amount_cents=subscription.monthly_price_cents,
                        due_date=period_start,
                        billing_period_start=period_start,
                        billing_period_end=period_end,
                        status=InvoiceStatus.PENDING,
                    )
                )
                changed = True
            subscription.next_invoice_date = add_months(subscription.next_invoice_date, 1)
            changed = True

    if subscription.canceled_at and subscription.canceled_at <= today:
        if subscription.status != SubscriptionStatus.CANCELED:
            subscription.status = SubscriptionStatus.CANCELED
            changed = True
        return changed

    has_overdue_invoice = any(invoice.status == InvoiceStatus.OVERDUE for invoice in subscription.invoices)
    if has_overdue_invoice and subscription.status != SubscriptionStatus.PAUSED:
        if subscription.status != SubscriptionStatus.PAST_DUE:
            subscription.status = SubscriptionStatus.PAST_DUE
            changed = True
    elif subscription.status == SubscriptionStatus.PAST_DUE:
        subscription.status = SubscriptionStatus.ACTIVE
        changed = True

    return changed
