def handler(event, context):
    order = event.get("order")

    if not order:
        raise ValueError("Missing 'order' in input")

    if order.get("inventory_status") != "RESERVED":
        raise ValueError("Cannot process payment: inventory not reserved")

    order["payment_status"] = "PAID"
    order["transaction_id"] = f"demo-{order['order_id']}"

    return order