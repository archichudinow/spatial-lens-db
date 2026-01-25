


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."project_status" AS ENUM (
    'development',
    'released',
    'archived'
);


ALTER TYPE "public"."project_status" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."auto_create_exploration_scenario"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Create an exploration scenario for the new option
  INSERT INTO scenarios (
    option_id,
    name,
    description,
    objective,
    start_coordinates,
    destination_coordinates,
    is_archived
  ) VALUES (
    NEW.id,
    'Exploration Scenario',
    'A free exploration scenario created with the option.',
    'You are free to explore',
    '{"x": 0, "y": 0, "z": 0}'::jsonb,
    '{"x": 0, "y": 0, "z": 0}'::jsonb,
    false
  );
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."auto_create_exploration_scenario"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_project_full"("p_project_id" "uuid") RETURNS json
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  result JSON;
BEGIN
  SELECT row_to_json(project_data)
  INTO result
  FROM (
    SELECT 
      p.*,
      (
        SELECT json_agg(
          json_build_object(
            'id', o.id,
            'name', o.name,
            'description', o.description,
            'model_url', o.model_url,
            'is_archived', o.is_archived,
            'created_at', o.created_at,
            'scenarios', (
              SELECT json_agg(
                json_build_object(
                  'id', s.id,
                  'name', s.name,
                  'description', s.description,
                  'objective', s.objective,
                  'start_coordinates', s.start_coordinates,
                  'destination_coordinates', s.destination_coordinates,
                  'is_archived', s.is_archived,
                  'created_at', s.created_at,
                  'records', (
                    SELECT json_agg(
                      json_build_object(
                        'id', r.id,
                        'raw_url', r.raw_url,
                        'record_url', r.record_url,
                        'length_ms', r.length_ms,
                        'device_type', r.device_type,
                        'created_at', r.created_at
                      )
                    )
                    FROM records r
                    WHERE r.scenario_id = s.id AND r.is_archived = false
                  )
                )
              )
              FROM scenarios s
              WHERE s.option_id = o.id AND s.is_archived = false
            )
          )
        )
        FROM project_options o
        WHERE o.project_id = p.id AND o.is_archived = false
      ) as options
    FROM projects p
    WHERE p.id = p_project_id
  ) project_data;
  
  RETURN result;
END;
$$;


ALTER FUNCTION "public"."get_project_full"("p_project_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rls_auto_enable"() RETURNS "event_trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
    AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$$;


ALTER FUNCTION "public"."rls_auto_enable"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."project_options" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "project_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "model_url" "text",
    "is_default" boolean DEFAULT false NOT NULL,
    "is_archived" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone
);


ALTER TABLE "public"."project_options" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."projects" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "status" "public"."project_status" DEFAULT 'development'::"public"."project_status" NOT NULL,
    "models_context" "text"[],
    "models_heatmap" "text",
    "spatial_lens_url" "text",
    "spatial_simulation_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone
);


ALTER TABLE "public"."projects" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."records" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "project_id" "uuid" NOT NULL,
    "option_id" "uuid" NOT NULL,
    "scenario_id" "uuid" NOT NULL,
    "raw_url" "text",
    "record_url" "text" NOT NULL,
    "length_ms" integer,
    "device_type" "text",
    "is_archived" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone,
    CONSTRAINT "records_device_type_check" CHECK (("device_type" = ANY (ARRAY['pc'::"text", 'vr'::"text"]))),
    CONSTRAINT "records_length_ms_check" CHECK ((("length_ms" IS NULL) OR ("length_ms" > 0)))
);


ALTER TABLE "public"."records" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."scenarios" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "option_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "start_coordinates" "jsonb" DEFAULT '{"x": 0.0, "y": 0.0, "z": 0.0}'::"jsonb" NOT NULL,
    "destination_coordinates" "jsonb" DEFAULT '{"x": 0.0, "y": 0.0, "z": 0.0}'::"jsonb" NOT NULL,
    "objective" "text" NOT NULL,
    "is_archived" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone
);


ALTER TABLE "public"."scenarios" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."projects_full" AS
 SELECT "id",
    "name",
    "description",
    "status",
    "models_context",
    "models_heatmap",
    "spatial_lens_url",
    "spatial_simulation_url",
    "created_at",
    "updated_at",
    ( SELECT "json_agg"("jsonb_build_object"('id', "o"."id", 'name', "o"."name", 'description', "o"."description", 'model_url', "o"."model_url", 'is_archived', "o"."is_archived", 'created_at', "o"."created_at", 'scenarios', ( SELECT "json_agg"("jsonb_build_object"('id', "s"."id", 'name', "s"."name", 'description', "s"."description", 'objective', "s"."objective", 'start_coordinates', "s"."start_coordinates", 'destination_coordinates', "s"."destination_coordinates", 'is_archived', "s"."is_archived", 'records_count', ( SELECT "count"(*) AS "count"
                           FROM "public"."records" "r"
                          WHERE (("r"."scenario_id" = "s"."id") AND ("r"."is_archived" = false))))) AS "json_agg"
                   FROM "public"."scenarios" "s"
                  WHERE (("s"."option_id" = "o"."id") AND ("s"."is_archived" = false))))) AS "json_agg"
           FROM "public"."project_options" "o"
          WHERE (("o"."project_id" = "p"."id") AND ("o"."is_archived" = false))) AS "options"
   FROM "public"."projects" "p";


ALTER VIEW "public"."projects_full" OWNER TO "postgres";


ALTER TABLE ONLY "public"."project_options"
    ADD CONSTRAINT "project_options_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."projects"
    ADD CONSTRAINT "projects_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."records"
    ADD CONSTRAINT "records_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."scenarios"
    ADD CONSTRAINT "scenarios_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_project_options_is_archived" ON "public"."project_options" USING "btree" ("is_archived");



CREATE INDEX "idx_project_options_is_default" ON "public"."project_options" USING "btree" ("is_default");



CREATE INDEX "idx_project_options_project_id" ON "public"."project_options" USING "btree" ("project_id");



CREATE INDEX "idx_projects_created_at" ON "public"."projects" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_projects_status" ON "public"."projects" USING "btree" ("status");



CREATE INDEX "idx_records_created_at" ON "public"."records" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_records_device_type" ON "public"."records" USING "btree" ("device_type");



CREATE INDEX "idx_records_is_archived" ON "public"."records" USING "btree" ("is_archived");



CREATE INDEX "idx_records_option_id" ON "public"."records" USING "btree" ("option_id");



CREATE INDEX "idx_records_project_id" ON "public"."records" USING "btree" ("project_id");



CREATE INDEX "idx_records_scenario_id" ON "public"."records" USING "btree" ("scenario_id");



CREATE INDEX "idx_scenarios_is_archived" ON "public"."scenarios" USING "btree" ("is_archived");



CREATE INDEX "idx_scenarios_option_id" ON "public"."scenarios" USING "btree" ("option_id");



CREATE OR REPLACE TRIGGER "trigger_auto_create_scenario" AFTER INSERT ON "public"."project_options" FOR EACH ROW EXECUTE FUNCTION "public"."auto_create_exploration_scenario"();



CREATE OR REPLACE TRIGGER "trigger_update_options_updated_at" BEFORE UPDATE ON "public"."project_options" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "trigger_update_projects_updated_at" BEFORE UPDATE ON "public"."projects" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "trigger_update_records_updated_at" BEFORE UPDATE ON "public"."records" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "trigger_update_scenarios_updated_at" BEFORE UPDATE ON "public"."scenarios" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



ALTER TABLE ONLY "public"."project_options"
    ADD CONSTRAINT "project_options_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."records"
    ADD CONSTRAINT "records_option_id_fkey" FOREIGN KEY ("option_id") REFERENCES "public"."project_options"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."records"
    ADD CONSTRAINT "records_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."records"
    ADD CONSTRAINT "records_scenario_id_fkey" FOREIGN KEY ("scenario_id") REFERENCES "public"."scenarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."scenarios"
    ADD CONSTRAINT "scenarios_option_id_fkey" FOREIGN KEY ("option_id") REFERENCES "public"."project_options"("id") ON DELETE CASCADE;



CREATE POLICY "Authenticated users can create project_options" ON "public"."project_options" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Authenticated users can create projects" ON "public"."projects" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Authenticated users can create scenarios" ON "public"."scenarios" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Authenticated users can delete project_options" ON "public"."project_options" FOR DELETE TO "authenticated" USING (true);



CREATE POLICY "Authenticated users can delete projects" ON "public"."projects" FOR DELETE TO "authenticated" USING (true);



CREATE POLICY "Authenticated users can delete records" ON "public"."records" FOR DELETE TO "authenticated" USING (true);



CREATE POLICY "Authenticated users can delete scenarios" ON "public"."scenarios" FOR DELETE TO "authenticated" USING (true);



CREATE POLICY "Authenticated users can update project_options" ON "public"."project_options" FOR UPDATE TO "authenticated" USING (true);



CREATE POLICY "Authenticated users can update projects" ON "public"."projects" FOR UPDATE TO "authenticated" USING (true);



CREATE POLICY "Authenticated users can update records" ON "public"."records" FOR UPDATE TO "authenticated" USING (true);



CREATE POLICY "Authenticated users can update scenarios" ON "public"."scenarios" FOR UPDATE TO "authenticated" USING (true);



CREATE POLICY "Public can create records" ON "public"."records" FOR INSERT WITH CHECK (true);



CREATE POLICY "Public can view all project_options" ON "public"."project_options" FOR SELECT USING (true);



CREATE POLICY "Public can view all projects" ON "public"."projects" FOR SELECT USING (true);



CREATE POLICY "Public can view all records" ON "public"."records" FOR SELECT USING (true);



CREATE POLICY "Public can view all scenarios" ON "public"."scenarios" FOR SELECT USING (true);



CREATE POLICY "Public users can view project_options" ON "public"."project_options" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Public users can view records" ON "public"."records" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Public users can view released projects" ON "public"."projects" FOR SELECT TO "anon" USING (("status" = 'released'::"public"."project_status"));



CREATE POLICY "Public users can view scenarios" ON "public"."scenarios" FOR SELECT TO "anon" USING (true);



ALTER TABLE "public"."project_options" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."projects" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."records" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."scenarios" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";

























































































































































GRANT ALL ON FUNCTION "public"."auto_create_exploration_scenario"() TO "anon";
GRANT ALL ON FUNCTION "public"."auto_create_exploration_scenario"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."auto_create_exploration_scenario"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_project_full"("p_project_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_project_full"("p_project_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_project_full"("p_project_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "anon";
GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";


















GRANT ALL ON TABLE "public"."project_options" TO "anon";
GRANT ALL ON TABLE "public"."project_options" TO "authenticated";
GRANT ALL ON TABLE "public"."project_options" TO "service_role";



GRANT ALL ON TABLE "public"."projects" TO "anon";
GRANT ALL ON TABLE "public"."projects" TO "authenticated";
GRANT ALL ON TABLE "public"."projects" TO "service_role";



GRANT ALL ON TABLE "public"."records" TO "anon";
GRANT ALL ON TABLE "public"."records" TO "authenticated";
GRANT ALL ON TABLE "public"."records" TO "service_role";



GRANT ALL ON TABLE "public"."scenarios" TO "anon";
GRANT ALL ON TABLE "public"."scenarios" TO "authenticated";
GRANT ALL ON TABLE "public"."scenarios" TO "service_role";



GRANT ALL ON TABLE "public"."projects_full" TO "anon";
GRANT ALL ON TABLE "public"."projects_full" TO "authenticated";
GRANT ALL ON TABLE "public"."projects_full" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";



































drop extension if exists "pg_net";


  create policy "Authenticated users can delete project files"
  on "storage"."objects"
  as permissive
  for delete
  to authenticated
using ((bucket_id = 'projects'::text));



  create policy "Authenticated users can delete"
  on "storage"."objects"
  as permissive
  for delete
  to authenticated
using (true);



  create policy "Authenticated users can read from projects bucket"
  on "storage"."objects"
  as permissive
  for select
  to authenticated
using ((bucket_id = 'projects'::text));



  create policy "Authenticated users can update project files"
  on "storage"."objects"
  as permissive
  for update
  to authenticated
using ((bucket_id = 'projects'::text));



  create policy "Authenticated users can update"
  on "storage"."objects"
  as permissive
  for update
  to authenticated
using (true)
with check (true);



  create policy "Authenticated users can upload project files"
  on "storage"."objects"
  as permissive
  for insert
  to authenticated
with check ((bucket_id = 'projects'::text));



  create policy "Authenticated users can upload"
  on "storage"."objects"
  as permissive
  for insert
  to authenticated
with check (true);



  create policy "Public can read from projects bucket"
  on "storage"."objects"
  as permissive
  for select
  to public
using ((bucket_id = 'projects'::text));



  create policy "Public can view project files"
  on "storage"."objects"
  as permissive
  for select
  to public
using ((bucket_id = 'projects'::text));



  create policy "Public read access"
  on "storage"."objects"
  as permissive
  for select
  to public
using (true);



  create policy "Public users can upload record files"
  on "storage"."objects"
  as permissive
  for insert
  to anon
with check (((bucket_id = 'projects'::text) AND ((storage.foldername(name))[1] IS NOT NULL)));



