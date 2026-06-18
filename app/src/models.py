"""
Database models for the Bagel Store application.
"""

from dataclasses import dataclass
from datetime import datetime
from typing import Optional


@dataclass
class Product:
    """Bagel product model"""
    id: int
    name: str
    description: str
    price: float

    @staticmethod
    def from_db_row(row):
        """Create Product from database row"""
        return Product(
            id=row[0],
            name=row[1],
            description=row[2],
            price=float(row[3])
        )


@dataclass
class Inventory:
    """Inventory tracking model"""
    product_id: int
    quantity: int
    last_updated: datetime

    @staticmethod
    def from_db_row(row):
        """Create Inventory from database row"""
        return Inventory(
            product_id=row[0],
            quantity=row[1],
            last_updated=row[2]
        )


@dataclass
class Order:
    """Customer order model"""
    id: int
    order_date: datetime
    total_amount: float
    status: str

    @staticmethod
    def from_db_row(row):
        """Create Order from database row"""
        return Order(
            id=row[0],
            order_date=row[1],
            total_amount=float(row[2]),
            status=row[3]
        )


@dataclass
class OrderItem:
    """Order line item model"""
    id: int
    order_id: int
    product_id: int
    quantity: int
    price: float

    @staticmethod
    def from_db_row(row):
        """Create OrderItem from database row"""
        return OrderItem(
            id=row[0],
            order_id=row[1],
            product_id=row[2],
            quantity=row[3],
            price=float(row[4])
        )
