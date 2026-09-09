import json


def handler(event, context):
    order = event.get("order")

    if not order:
        raise ValueError("Missing 'order' in input")

    required_fields = ["order_id", "customer_id", "items", "total_amount"]
    for field in required_fields:
        if field not in order:
            raise ValueError(f"Missing required field: {field}")

    if not order["items"] or len(order["items"]) == 0:
        raise ValueError("Order must contain at least one item")

    if order["total_amount"] <= 0:
        raise ValueError("total_amount must be positive")

    return order