We are redesigning our request pipeline for handling metadata + file uploads and want to ensure the database and Supabase setup fully supports a correct multi-phase flow.

Your task is to audit and propose changes to the DB schema, constraints, policies, and Supabase storage usage so the system is safe, consistent, and UX-friendly.

🎯 Goal

Ensure the database cannot enter an invalid state (e.g. completed records without files) and cleanly supports async uploads, retries, and progress-based UX.

1️⃣ Core lifecycle we want the DB to support

Every entity that includes file uploads must follow this lifecycle:

draft – metadata created, no uploads started

uploading – files are being uploaded

completed – all required files exist and are validated

failed – upload or processing failed, recoverable

The DB must enforce this lifecycle as much as possible.

2️⃣ Expected client-side flow (important context)

The frontend (React + React Query) will behave as follows:

Create metadata

Client sends metadata only

Backend creates DB row with status = 'draft' or 'uploading'

Returns entity_id

Upload files

Files upload AFTER the row exists

Files may upload one-by-one or in parallel

Upload progress is tracked client-side

Upload failures should NOT corrupt the DB record

Finalize

Client calls a finalize endpoint / RPC

Backend verifies:

all required files exist

files are linked to the entity

Only then update status = 'completed'

The client will never assume completion without DB confirmation.

3️⃣ Your tasks

Please analyze and propose:

A. Database schema

Whether current tables properly support:

upload states

partial uploads

retries

Whether we need:

a status enum

a separate files table

required file counts / types

B. Supabase Storage integration

How files should be named / structured (e.g. per entity ID)

How to reliably associate uploaded files with DB rows

Whether uploads should be allowed only after a DB row exists

C. Constraints & safeguards

What constraints or checks can prevent:

marking records as completed without files

orphaned uploads

What validations should happen at finalization time, not earlier

D. Failure & recovery

How to handle:

interrupted uploads

abandoned drafts

failed uploads that should be retryable

Whether background cleanup jobs or cron logic are needed

4️⃣ Output expected from you

Please produce:

A recommended DB schema (tables, columns, enums)

A status transition diagram (allowed vs forbidden transitions)

A Supabase Storage strategy

A clear guide for the client-side agent, explaining:

which DB guarantees exist

which checks must happen client-side

which steps must never be skipped

Assume the client agent will strictly follow your guide.

Focus on correctness, data safety, and long-term maintainability.