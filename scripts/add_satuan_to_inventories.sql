-- Migration to add 'satuan' (unit) column to the inventories table
ALTER TABLE inventories ADD COLUMN IF NOT EXISTS satuan VARCHAR(50) DEFAULT 'pcs';
