CREATE TYPE "StructureNodeType" AS ENUM ('ZONE', 'STREET', 'BUILDING', 'FLOOR');
CREATE TYPE "StructureNodeStatus" AS ENUM ('ACTIVE', 'ARCHIVED');

CREATE TABLE "estate_structure_nodes" (
  "id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "type" "StructureNodeType" NOT NULL,
  "name" VARCHAR(120) NOT NULL,
  "code" VARCHAR(60),
  "building_type" VARCHAR(80),
  "floor_count" INTEGER,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "status" "StructureNodeStatus" NOT NULL DEFAULT 'ACTIVE',
  "created_by_id" UUID NOT NULL,
  "updated_by_id" UUID,
  "archived_at" TIMESTAMPTZ(3),
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(3) NOT NULL,
  CONSTRAINT "estate_structure_nodes_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "estate_structure_nodes_estate_id_fkey" FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_structure_nodes_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_structure_nodes_updated_by_id_fkey" FOREIGN KEY ("updated_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_structure_nodes_floor_count_check" CHECK ("floor_count" IS NULL OR ("type" = 'BUILDING' AND "floor_count" BETWEEN 1 AND 300)),
  CONSTRAINT "estate_structure_nodes_sort_order_check" CHECK ("sort_order" >= 0)
);
CREATE UNIQUE INDEX "estate_structure_nodes_estate_type_code_key" ON "estate_structure_nodes"("estate_id", "type", "code");
CREATE INDEX "estate_structure_nodes_estate_type_status_sort_idx" ON "estate_structure_nodes"("estate_id", "type", "status", "sort_order");

CREATE TABLE "estate_structure_parents" (
  "child_id" UUID NOT NULL,
  "parent_id" UUID NOT NULL,
  CONSTRAINT "estate_structure_parents_pkey" PRIMARY KEY ("child_id", "parent_id"),
  CONSTRAINT "estate_structure_parents_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "estate_structure_nodes"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_structure_parents_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "estate_structure_nodes"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_structure_parents_not_self_check" CHECK ("child_id" <> "parent_id")
);
CREATE INDEX "estate_structure_parents_parent_id_idx" ON "estate_structure_parents"("parent_id");

CREATE TABLE "estate_property_structure" (
  "property_id" UUID NOT NULL,
  "node_id" UUID NOT NULL,
  CONSTRAINT "estate_property_structure_pkey" PRIMARY KEY ("property_id", "node_id"),
  CONSTRAINT "estate_property_structure_property_id_fkey" FOREIGN KEY ("property_id") REFERENCES "estate_properties"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_property_structure_node_id_fkey" FOREIGN KEY ("node_id") REFERENCES "estate_structure_nodes"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX "estate_property_structure_node_id_idx" ON "estate_property_structure"("node_id");
