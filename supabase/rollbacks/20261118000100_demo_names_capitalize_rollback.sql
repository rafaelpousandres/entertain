-- ============================================================================
-- ROLLBACK (safety net) for 20261118000100_demo_names_capitalize.sql
--
-- NOT A MIGRATION: it lives outside supabase/migrations on purpose so that
-- `supabase db push` can never pick it up. Run it by hand, and only on the
-- director's explicit decision.
--
-- Restores the lowercase initial of the demo ingredient names and their name
-- translations, to the EXACT values the template had before the capitalisation
-- (snapshot taken from production on 2026-11-18, embedded below: 60 names and
-- 182 translations). Dishes and drinks are not involved — the forward
-- migration changed none of them.
--
-- SAME SAFETY RULES as the forward migration:
--   • a demo copy is recognised by its deterministic id;
--   • a copy is restored only while its value is still identical to the
--     template's current (capitalised) value — anything a user has renamed
--     since is left alone. Hence copies are processed BEFORE the template.
--
-- NOTE: accounts created after the forward migration received capitalised
-- copies; they are identical to the template, so this lowercases them too
-- (every account ends up in the pre-migration convention).
--
-- One DO block = one transaction; aborts if the template is not fully restored.
-- ============================================================================

do $$
declare
  v_template constant uuid := '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52';
  v_n bigint;
  v_total bigint := 0;
  v_left bigint;
begin
  create temp table _old_name (id uuid primary key, old_name text not null) on commit drop;
  insert into _old_name (id, old_name) values
    ('04a6b069-86e2-46f3-acfa-dacee0707cf6'::uuid, 'mushrooms'),
    ('07b15180-2cc3-4645-ac86-da793f87d498'::uuid, 'cream cheese'),
    ('07b78080-882b-42a5-addd-f251ae49d8bb'::uuid, 'avocado'),
    ('0e7f6156-eb1c-469b-93f8-0f84f6b81a71'::uuid, 'bean sprouts'),
    ('12fe7e21-07ee-493a-a5bb-39ad4a45b20a'::uuid, 'chestnuts'),
    ('14d30440-86dd-4ca3-9531-c49a60dad145'::uuid, 'tomato'),
    ('16018043-4403-4cc6-97ae-b981b1a82458'::uuid, 'saffron threads'),
    ('18ba2971-0ddc-4586-87fd-712681208635'::uuid, 'whole goose'),
    ('1f03bf45-89cd-4bd9-90e7-c61181c19099'::uuid, 'olive oil'),
    ('218cb75a-a9ed-4240-8713-bdbac564088b'::uuid, 'cucumber'),
    ('2219823e-67bc-427a-9539-048009dca5aa'::uuid, 'ricotta'),
    ('23e68829-c2e7-4b67-8261-cc5f696cdfe7'::uuid, 'firm tofu'),
    ('27b35bc3-86e1-4460-9884-ddc43e0c0cd6'::uuid, 'parsley'),
    ('2e7a5461-3d24-4fef-bfcd-63594bf23f3d'::uuid, 'sage leaves'),
    ('2f2c4498-254f-4880-a46e-c91b2f31fb9c'::uuid, 'fresh orange juice'),
    ('322b45a0-347b-49ac-994f-4ce4b732923e'::uuid, 'kalamata olives'),
    ('3762a7ab-c182-4e34-99bb-0e7cd58fc370'::uuid, 'pastry flour'),
    ('3c91bc42-1084-4980-8304-dcae30cd522b'::uuid, 'baguette'),
    ('4bfe399a-313c-4020-a6ed-89ebfe6ddb0a'::uuid, 'celery stalks'),
    ('514e00a4-c6af-4564-a28d-d95f45b01d6b'::uuid, 'strawberries'),
    ('53047bc9-c994-4977-9381-cab5651b891a'::uuid, 'puff pastry'),
    ('773183b7-6142-46b2-b782-e72364709619'::uuid, 'arborio rice'),
    ('7768d83e-48f3-4377-a3cc-e27f7aee573f'::uuid, 'sugar'),
    ('78bcfb36-88e2-4f1d-adfd-f214099ac2ff'::uuid, 'pineapple'),
    ('7a884519-ec68-4bbc-b31b-7e6638a13d71'::uuid, 'spinach'),
    ('7c3c7726-ea7f-4681-95bf-6ce4715f6a75'::uuid, 'rice noodles'),
    ('7f6b6e79-02af-4c55-a7b0-01bdf0c958f2'::uuid, 'beef tenderloin'),
    ('899773e4-4781-43bb-b91d-08d0ebdd4b76'::uuid, 'ladyfingers'),
    ('8b7791a7-c9ed-46e1-ab0a-91dacddf38f1'::uuid, 'peanuts'),
    ('8bdcec85-a991-4960-9464-93ef99eda3b3'::uuid, 'feta cheese'),
    ('8c4b12f7-15d9-45ff-ac09-8d633ae0ea4d'::uuid, 'heavy cream'),
    ('91bc8712-ca9f-42aa-966e-0106b76c43db'::uuid, 'parmesan'),
    ('9213ac47-567a-4ea7-86a0-93802b24d95f'::uuid, 'capers'),
    ('967c4d22-029b-4528-a4db-de1c40a0356b'::uuid, 'marsala wine'),
    ('9835da95-c154-4e6d-99f7-e1a43dc2e899'::uuid, 'fresh thyme'),
    ('98cb1e9f-7557-47ed-b4c0-3d52d0de9cda'::uuid, 'large eggs'),
    ('99f1f3ab-a6b0-4ac0-a0a6-d43114712eee'::uuid, 'beef stock'),
    ('a00a29cc-2631-48f1-bb79-ccf002bd4e4c'::uuid, 'espresso coffee'),
    ('a649aff8-952d-4d85-be28-c79af71d4570'::uuid, 'dark chocolate'),
    ('ade71ee9-7dcc-485e-bd0a-103f143d6dc2'::uuid, 'yellow onion'),
    ('b038f1c7-313e-40a1-b6ce-8abb41a2bb0d'::uuid, 'carrots'),
    ('b07e7338-e930-41f7-b670-0b9e845d81d7'::uuid, 'smoked salmon'),
    ('b586ef00-df11-443b-b8fd-1d2fb8df2c3d'::uuid, 'lemons'),
    ('b9d15c0a-3e13-47d2-b8dc-c644b7193846'::uuid, 'truffle oil'),
    ('be021b15-a6cb-4e10-920f-078d138b8245'::uuid, 'butter'),
    ('c0412876-5c0b-4ab9-b8ad-05fc8e5c1a70'::uuid, 'veal shanks'),
    ('c0ae605b-2d22-405e-ba43-73e8a476660a'::uuid, 'dry white wine'),
    ('c0cb6d26-7114-4028-8115-71f6dcb5154f'::uuid, 'mascarpone'),
    ('c5c1dfb8-690b-4d9f-843a-48bdbecf64c4'::uuid, 'potatoes'),
    ('ce85b094-4430-4bf8-8ad0-77bd2a788573'::uuid, 'oysters'),
    ('d02be85d-8a28-44bb-8147-7b8df8811ef6'::uuid, 'garlic cloves'),
    ('d1840c2c-4094-4b16-b9a3-411e7a4070b0'::uuid, 'soy sauce'),
    ('d6e06e97-f9bb-427c-a5b2-895966e9b2fb'::uuid, 'cocoa powder'),
    ('d82a0f7d-d0b5-4517-b213-cf7c2d876ce0'::uuid, 'apples'),
    ('db574d2e-dccc-4f3c-b355-ef97c14cdd28'::uuid, 'prosecco'),
    ('df9f4556-59a2-4563-bb92-719424dff0e8'::uuid, 'sourdough bread'),
    ('dfb2321c-d029-4f2d-aca0-377132da85e9'::uuid, 'limes'),
    ('e293e5b7-600f-448f-9ef3-dcb815a4cb4a'::uuid, 'fresh mint'),
    ('e841d063-587d-436c-b4d3-4876fd5b645f'::uuid, 'blueberries'),
    ('eb04fb7c-e608-4f67-855b-cdba6ad4e734'::uuid, 'basil');

  create temp table _old_tr (id uuid not null, locale public.profile_locale not null,
                             old_text text not null, primary key (id, locale)) on commit drop;
  insert into _old_tr (id, locale, old_text) values
    ('04a6b069-86e2-46f3-acfa-dacee0707cf6'::uuid, 'ca'::public.profile_locale, 'bolets'),
    ('04a6b069-86e2-46f3-acfa-dacee0707cf6'::uuid, 'en'::public.profile_locale, 'mushrooms'),
    ('04a6b069-86e2-46f3-acfa-dacee0707cf6'::uuid, 'es'::public.profile_locale, 'champiñones'),
    ('07b15180-2cc3-4645-ac86-da793f87d498'::uuid, 'ca'::public.profile_locale, 'formatge cremós'),
    ('07b15180-2cc3-4645-ac86-da793f87d498'::uuid, 'en'::public.profile_locale, 'cream cheese'),
    ('07b15180-2cc3-4645-ac86-da793f87d498'::uuid, 'es'::public.profile_locale, 'queso crema'),
    ('07b78080-882b-42a5-addd-f251ae49d8bb'::uuid, 'ca'::public.profile_locale, 'alvocat'),
    ('07b78080-882b-42a5-addd-f251ae49d8bb'::uuid, 'en'::public.profile_locale, 'avocado'),
    ('07b78080-882b-42a5-addd-f251ae49d8bb'::uuid, 'es'::public.profile_locale, 'aguacate'),
    ('0e7f6156-eb1c-469b-93f8-0f84f6b81a71'::uuid, 'ca'::public.profile_locale, 'brots de soja'),
    ('0e7f6156-eb1c-469b-93f8-0f84f6b81a71'::uuid, 'en'::public.profile_locale, 'bean sprouts'),
    ('0e7f6156-eb1c-469b-93f8-0f84f6b81a71'::uuid, 'es'::public.profile_locale, 'brotes de soja'),
    ('12fe7e21-07ee-493a-a5bb-39ad4a45b20a'::uuid, 'ca'::public.profile_locale, 'castanyes'),
    ('12fe7e21-07ee-493a-a5bb-39ad4a45b20a'::uuid, 'en'::public.profile_locale, 'chestnuts'),
    ('12fe7e21-07ee-493a-a5bb-39ad4a45b20a'::uuid, 'es'::public.profile_locale, 'castañas'),
    ('14d30440-86dd-4ca3-9531-c49a60dad145'::uuid, 'ca'::public.profile_locale, 'tomàquet'),
    ('14d30440-86dd-4ca3-9531-c49a60dad145'::uuid, 'en'::public.profile_locale, 'tomato'),
    ('14d30440-86dd-4ca3-9531-c49a60dad145'::uuid, 'es'::public.profile_locale, 'tomate'),
    ('16018043-4403-4cc6-97ae-b981b1a82458'::uuid, 'ca'::public.profile_locale, 'fils de safrà'),
    ('16018043-4403-4cc6-97ae-b981b1a82458'::uuid, 'en'::public.profile_locale, 'saffron threads'),
    ('16018043-4403-4cc6-97ae-b981b1a82458'::uuid, 'es'::public.profile_locale, 'hebras de azafrán'),
    ('18ba2971-0ddc-4586-87fd-712681208635'::uuid, 'ca'::public.profile_locale, 'oca sencera'),
    ('18ba2971-0ddc-4586-87fd-712681208635'::uuid, 'en'::public.profile_locale, 'whole goose'),
    ('18ba2971-0ddc-4586-87fd-712681208635'::uuid, 'es'::public.profile_locale, 'oca entera'),
    ('1f03bf45-89cd-4bd9-90e7-c61181c19099'::uuid, 'ca'::public.profile_locale, 'oli d''oliva'),
    ('1f03bf45-89cd-4bd9-90e7-c61181c19099'::uuid, 'en'::public.profile_locale, 'olive oil'),
    ('1f03bf45-89cd-4bd9-90e7-c61181c19099'::uuid, 'es'::public.profile_locale, 'aceite de oliva'),
    ('218cb75a-a9ed-4240-8713-bdbac564088b'::uuid, 'ca'::public.profile_locale, 'cogombre'),
    ('218cb75a-a9ed-4240-8713-bdbac564088b'::uuid, 'en'::public.profile_locale, 'cucumber'),
    ('218cb75a-a9ed-4240-8713-bdbac564088b'::uuid, 'es'::public.profile_locale, 'pepino'),
    ('2219823e-67bc-427a-9539-048009dca5aa'::uuid, 'ca'::public.profile_locale, 'ricotta'),
    ('2219823e-67bc-427a-9539-048009dca5aa'::uuid, 'en'::public.profile_locale, 'ricotta'),
    ('2219823e-67bc-427a-9539-048009dca5aa'::uuid, 'es'::public.profile_locale, 'ricotta'),
    ('23e68829-c2e7-4b67-8261-cc5f696cdfe7'::uuid, 'ca'::public.profile_locale, 'tofu ferm'),
    ('23e68829-c2e7-4b67-8261-cc5f696cdfe7'::uuid, 'en'::public.profile_locale, 'firm tofu'),
    ('23e68829-c2e7-4b67-8261-cc5f696cdfe7'::uuid, 'es'::public.profile_locale, 'tofu firme'),
    ('27b35bc3-86e1-4460-9884-ddc43e0c0cd6'::uuid, 'ca'::public.profile_locale, 'julivert'),
    ('27b35bc3-86e1-4460-9884-ddc43e0c0cd6'::uuid, 'en'::public.profile_locale, 'parsley'),
    ('27b35bc3-86e1-4460-9884-ddc43e0c0cd6'::uuid, 'es'::public.profile_locale, 'perejil'),
    ('2e7a5461-3d24-4fef-bfcd-63594bf23f3d'::uuid, 'ca'::public.profile_locale, 'fulles de sàlvia'),
    ('2e7a5461-3d24-4fef-bfcd-63594bf23f3d'::uuid, 'en'::public.profile_locale, 'sage leaves'),
    ('2e7a5461-3d24-4fef-bfcd-63594bf23f3d'::uuid, 'es'::public.profile_locale, 'hojas de salvia'),
    ('2f2c4498-254f-4880-a46e-c91b2f31fb9c'::uuid, 'ca'::public.profile_locale, 'suc de taronja fresc'),
    ('2f2c4498-254f-4880-a46e-c91b2f31fb9c'::uuid, 'en'::public.profile_locale, 'fresh orange juice'),
    ('2f2c4498-254f-4880-a46e-c91b2f31fb9c'::uuid, 'es'::public.profile_locale, 'zumo de naranja fresco'),
    ('322b45a0-347b-49ac-994f-4ce4b732923e'::uuid, 'ca'::public.profile_locale, 'olives kalamata'),
    ('322b45a0-347b-49ac-994f-4ce4b732923e'::uuid, 'en'::public.profile_locale, 'kalamata olives'),
    ('322b45a0-347b-49ac-994f-4ce4b732923e'::uuid, 'es'::public.profile_locale, 'aceitunas kalamata'),
    ('3762a7ab-c182-4e34-99bb-0e7cd58fc370'::uuid, 'ca'::public.profile_locale, 'farina de rebosteria'),
    ('3762a7ab-c182-4e34-99bb-0e7cd58fc370'::uuid, 'en'::public.profile_locale, 'pastry flour'),
    ('3762a7ab-c182-4e34-99bb-0e7cd58fc370'::uuid, 'es'::public.profile_locale, 'harina de repostería'),
    ('3c91bc42-1084-4980-8304-dcae30cd522b'::uuid, 'ca'::public.profile_locale, 'baguette'),
    ('3c91bc42-1084-4980-8304-dcae30cd522b'::uuid, 'en'::public.profile_locale, 'baguette'),
    ('3c91bc42-1084-4980-8304-dcae30cd522b'::uuid, 'es'::public.profile_locale, 'baguette'),
    ('4bfe399a-313c-4020-a6ed-89ebfe6ddb0a'::uuid, 'ca'::public.profile_locale, 'tiges d''api'),
    ('4bfe399a-313c-4020-a6ed-89ebfe6ddb0a'::uuid, 'en'::public.profile_locale, 'celery stalks'),
    ('4bfe399a-313c-4020-a6ed-89ebfe6ddb0a'::uuid, 'es'::public.profile_locale, 'tallos de apio'),
    ('514e00a4-c6af-4564-a28d-d95f45b01d6b'::uuid, 'ca'::public.profile_locale, 'maduixes'),
    ('514e00a4-c6af-4564-a28d-d95f45b01d6b'::uuid, 'en'::public.profile_locale, 'strawberries'),
    ('514e00a4-c6af-4564-a28d-d95f45b01d6b'::uuid, 'es'::public.profile_locale, 'fresas'),
    ('53047bc9-c994-4977-9381-cab5651b891a'::uuid, 'ca'::public.profile_locale, 'pasta de full'),
    ('53047bc9-c994-4977-9381-cab5651b891a'::uuid, 'en'::public.profile_locale, 'puff pastry'),
    ('53047bc9-c994-4977-9381-cab5651b891a'::uuid, 'es'::public.profile_locale, 'hojaldre'),
    ('7455170d-c38e-4387-a03b-fdee21a3a70a'::uuid, 'ca'::public.profile_locale, 'farina 00'),
    ('7455170d-c38e-4387-a03b-fdee21a3a70a'::uuid, 'es'::public.profile_locale, 'harina 00'),
    ('773183b7-6142-46b2-b782-e72364709619'::uuid, 'ca'::public.profile_locale, 'arròs arborio'),
    ('773183b7-6142-46b2-b782-e72364709619'::uuid, 'en'::public.profile_locale, 'arborio rice'),
    ('773183b7-6142-46b2-b782-e72364709619'::uuid, 'es'::public.profile_locale, 'arroz arborio'),
    ('7768d83e-48f3-4377-a3cc-e27f7aee573f'::uuid, 'ca'::public.profile_locale, 'sucre'),
    ('7768d83e-48f3-4377-a3cc-e27f7aee573f'::uuid, 'en'::public.profile_locale, 'sugar'),
    ('7768d83e-48f3-4377-a3cc-e27f7aee573f'::uuid, 'es'::public.profile_locale, 'azúcar'),
    ('78bcfb36-88e2-4f1d-adfd-f214099ac2ff'::uuid, 'ca'::public.profile_locale, 'pinya'),
    ('78bcfb36-88e2-4f1d-adfd-f214099ac2ff'::uuid, 'en'::public.profile_locale, 'pineapple'),
    ('78bcfb36-88e2-4f1d-adfd-f214099ac2ff'::uuid, 'es'::public.profile_locale, 'piña'),
    ('7a884519-ec68-4bbc-b31b-7e6638a13d71'::uuid, 'ca'::public.profile_locale, 'espinacs'),
    ('7a884519-ec68-4bbc-b31b-7e6638a13d71'::uuid, 'en'::public.profile_locale, 'spinach'),
    ('7a884519-ec68-4bbc-b31b-7e6638a13d71'::uuid, 'es'::public.profile_locale, 'espinacas'),
    ('7c3c7726-ea7f-4681-95bf-6ce4715f6a75'::uuid, 'ca'::public.profile_locale, 'fideus d''arròs'),
    ('7c3c7726-ea7f-4681-95bf-6ce4715f6a75'::uuid, 'en'::public.profile_locale, 'rice noodles'),
    ('7c3c7726-ea7f-4681-95bf-6ce4715f6a75'::uuid, 'es'::public.profile_locale, 'fideos de arroz'),
    ('7f6b6e79-02af-4c55-a7b0-01bdf0c958f2'::uuid, 'ca'::public.profile_locale, 'filet de vedella'),
    ('7f6b6e79-02af-4c55-a7b0-01bdf0c958f2'::uuid, 'en'::public.profile_locale, 'beef tenderloin'),
    ('7f6b6e79-02af-4c55-a7b0-01bdf0c958f2'::uuid, 'es'::public.profile_locale, 'solomillo de ternera'),
    ('899773e4-4781-43bb-b91d-08d0ebdd4b76'::uuid, 'ca'::public.profile_locale, 'melindros'),
    ('899773e4-4781-43bb-b91d-08d0ebdd4b76'::uuid, 'en'::public.profile_locale, 'ladyfingers'),
    ('899773e4-4781-43bb-b91d-08d0ebdd4b76'::uuid, 'es'::public.profile_locale, 'bizcochos de soletilla'),
    ('8b7791a7-c9ed-46e1-ab0a-91dacddf38f1'::uuid, 'ca'::public.profile_locale, 'cacauets'),
    ('8b7791a7-c9ed-46e1-ab0a-91dacddf38f1'::uuid, 'en'::public.profile_locale, 'peanuts'),
    ('8b7791a7-c9ed-46e1-ab0a-91dacddf38f1'::uuid, 'es'::public.profile_locale, 'cacahuetes'),
    ('8bdcec85-a991-4960-9464-93ef99eda3b3'::uuid, 'ca'::public.profile_locale, 'formatge feta'),
    ('8bdcec85-a991-4960-9464-93ef99eda3b3'::uuid, 'en'::public.profile_locale, 'feta cheese'),
    ('8bdcec85-a991-4960-9464-93ef99eda3b3'::uuid, 'es'::public.profile_locale, 'queso feta'),
    ('8c4b12f7-15d9-45ff-ac09-8d633ae0ea4d'::uuid, 'ca'::public.profile_locale, 'nata per muntar'),
    ('8c4b12f7-15d9-45ff-ac09-8d633ae0ea4d'::uuid, 'en'::public.profile_locale, 'heavy cream'),
    ('8c4b12f7-15d9-45ff-ac09-8d633ae0ea4d'::uuid, 'es'::public.profile_locale, 'nata para montar'),
    ('91bc8712-ca9f-42aa-966e-0106b76c43db'::uuid, 'ca'::public.profile_locale, 'parmesà'),
    ('91bc8712-ca9f-42aa-966e-0106b76c43db'::uuid, 'en'::public.profile_locale, 'parmesan'),
    ('91bc8712-ca9f-42aa-966e-0106b76c43db'::uuid, 'es'::public.profile_locale, 'parmesano'),
    ('9213ac47-567a-4ea7-86a0-93802b24d95f'::uuid, 'ca'::public.profile_locale, 'tàperes'),
    ('9213ac47-567a-4ea7-86a0-93802b24d95f'::uuid, 'en'::public.profile_locale, 'capers'),
    ('9213ac47-567a-4ea7-86a0-93802b24d95f'::uuid, 'es'::public.profile_locale, 'alcaparras'),
    ('967c4d22-029b-4528-a4db-de1c40a0356b'::uuid, 'ca'::public.profile_locale, 'vi marsala'),
    ('967c4d22-029b-4528-a4db-de1c40a0356b'::uuid, 'en'::public.profile_locale, 'marsala wine'),
    ('967c4d22-029b-4528-a4db-de1c40a0356b'::uuid, 'es'::public.profile_locale, 'vino marsala'),
    ('9835da95-c154-4e6d-99f7-e1a43dc2e899'::uuid, 'ca'::public.profile_locale, 'farigola fresca'),
    ('9835da95-c154-4e6d-99f7-e1a43dc2e899'::uuid, 'en'::public.profile_locale, 'fresh thyme'),
    ('9835da95-c154-4e6d-99f7-e1a43dc2e899'::uuid, 'es'::public.profile_locale, 'tomillo fresco'),
    ('98cb1e9f-7557-47ed-b4c0-3d52d0de9cda'::uuid, 'ca'::public.profile_locale, 'ous grans'),
    ('98cb1e9f-7557-47ed-b4c0-3d52d0de9cda'::uuid, 'en'::public.profile_locale, 'large eggs'),
    ('98cb1e9f-7557-47ed-b4c0-3d52d0de9cda'::uuid, 'es'::public.profile_locale, 'huevos grandes'),
    ('99f1f3ab-a6b0-4ac0-a0a6-d43114712eee'::uuid, 'ca'::public.profile_locale, 'brou de vedella'),
    ('99f1f3ab-a6b0-4ac0-a0a6-d43114712eee'::uuid, 'en'::public.profile_locale, 'beef stock'),
    ('99f1f3ab-a6b0-4ac0-a0a6-d43114712eee'::uuid, 'es'::public.profile_locale, 'caldo de ternera'),
    ('a00a29cc-2631-48f1-bb79-ccf002bd4e4c'::uuid, 'ca'::public.profile_locale, 'cafè exprés'),
    ('a00a29cc-2631-48f1-bb79-ccf002bd4e4c'::uuid, 'en'::public.profile_locale, 'espresso coffee'),
    ('a00a29cc-2631-48f1-bb79-ccf002bd4e4c'::uuid, 'es'::public.profile_locale, 'café expreso'),
    ('a649aff8-952d-4d85-be28-c79af71d4570'::uuid, 'ca'::public.profile_locale, 'xocolata negra'),
    ('a649aff8-952d-4d85-be28-c79af71d4570'::uuid, 'en'::public.profile_locale, 'dark chocolate'),
    ('a649aff8-952d-4d85-be28-c79af71d4570'::uuid, 'es'::public.profile_locale, 'chocolate negro'),
    ('ade71ee9-7dcc-485e-bd0a-103f143d6dc2'::uuid, 'ca'::public.profile_locale, 'ceba groga'),
    ('ade71ee9-7dcc-485e-bd0a-103f143d6dc2'::uuid, 'en'::public.profile_locale, 'yellow onion'),
    ('ade71ee9-7dcc-485e-bd0a-103f143d6dc2'::uuid, 'es'::public.profile_locale, 'cebolla amarilla'),
    ('b038f1c7-313e-40a1-b6ce-8abb41a2bb0d'::uuid, 'ca'::public.profile_locale, 'pastanagues'),
    ('b038f1c7-313e-40a1-b6ce-8abb41a2bb0d'::uuid, 'en'::public.profile_locale, 'carrots'),
    ('b038f1c7-313e-40a1-b6ce-8abb41a2bb0d'::uuid, 'es'::public.profile_locale, 'zanahorias'),
    ('b07e7338-e930-41f7-b670-0b9e845d81d7'::uuid, 'ca'::public.profile_locale, 'salmó fumat'),
    ('b07e7338-e930-41f7-b670-0b9e845d81d7'::uuid, 'en'::public.profile_locale, 'smoked salmon'),
    ('b07e7338-e930-41f7-b670-0b9e845d81d7'::uuid, 'es'::public.profile_locale, 'salmón ahumado'),
    ('b586ef00-df11-443b-b8fd-1d2fb8df2c3d'::uuid, 'ca'::public.profile_locale, 'llimones'),
    ('b586ef00-df11-443b-b8fd-1d2fb8df2c3d'::uuid, 'en'::public.profile_locale, 'lemons'),
    ('b586ef00-df11-443b-b8fd-1d2fb8df2c3d'::uuid, 'es'::public.profile_locale, 'limones'),
    ('b9d15c0a-3e13-47d2-b8dc-c644b7193846'::uuid, 'ca'::public.profile_locale, 'oli de tòfona'),
    ('b9d15c0a-3e13-47d2-b8dc-c644b7193846'::uuid, 'en'::public.profile_locale, 'truffle oil'),
    ('b9d15c0a-3e13-47d2-b8dc-c644b7193846'::uuid, 'es'::public.profile_locale, 'aceite de trufa'),
    ('be021b15-a6cb-4e10-920f-078d138b8245'::uuid, 'ca'::public.profile_locale, 'mantega'),
    ('be021b15-a6cb-4e10-920f-078d138b8245'::uuid, 'en'::public.profile_locale, 'butter'),
    ('be021b15-a6cb-4e10-920f-078d138b8245'::uuid, 'es'::public.profile_locale, 'mantequilla'),
    ('c0412876-5c0b-4ab9-b8ad-05fc8e5c1a70'::uuid, 'ca'::public.profile_locale, 'jarrets de vedella'),
    ('c0412876-5c0b-4ab9-b8ad-05fc8e5c1a70'::uuid, 'en'::public.profile_locale, 'veal shanks'),
    ('c0412876-5c0b-4ab9-b8ad-05fc8e5c1a70'::uuid, 'es'::public.profile_locale, 'osobuco de ternera'),
    ('c0ae605b-2d22-405e-ba43-73e8a476660a'::uuid, 'ca'::public.profile_locale, 'vi blanc sec'),
    ('c0ae605b-2d22-405e-ba43-73e8a476660a'::uuid, 'en'::public.profile_locale, 'dry white wine'),
    ('c0ae605b-2d22-405e-ba43-73e8a476660a'::uuid, 'es'::public.profile_locale, 'vino blanco seco'),
    ('c0cb6d26-7114-4028-8115-71f6dcb5154f'::uuid, 'ca'::public.profile_locale, 'mascarpone'),
    ('c0cb6d26-7114-4028-8115-71f6dcb5154f'::uuid, 'en'::public.profile_locale, 'mascarpone'),
    ('c0cb6d26-7114-4028-8115-71f6dcb5154f'::uuid, 'es'::public.profile_locale, 'mascarpone'),
    ('c5c1dfb8-690b-4d9f-843a-48bdbecf64c4'::uuid, 'ca'::public.profile_locale, 'patates'),
    ('c5c1dfb8-690b-4d9f-843a-48bdbecf64c4'::uuid, 'en'::public.profile_locale, 'potatoes'),
    ('c5c1dfb8-690b-4d9f-843a-48bdbecf64c4'::uuid, 'es'::public.profile_locale, 'patatas'),
    ('ce85b094-4430-4bf8-8ad0-77bd2a788573'::uuid, 'ca'::public.profile_locale, 'ostres'),
    ('ce85b094-4430-4bf8-8ad0-77bd2a788573'::uuid, 'en'::public.profile_locale, 'oysters'),
    ('ce85b094-4430-4bf8-8ad0-77bd2a788573'::uuid, 'es'::public.profile_locale, 'ostras'),
    ('d02be85d-8a28-44bb-8147-7b8df8811ef6'::uuid, 'ca'::public.profile_locale, 'grans d''all'),
    ('d02be85d-8a28-44bb-8147-7b8df8811ef6'::uuid, 'en'::public.profile_locale, 'garlic cloves'),
    ('d02be85d-8a28-44bb-8147-7b8df8811ef6'::uuid, 'es'::public.profile_locale, 'dientes de ajo'),
    ('d1840c2c-4094-4b16-b9a3-411e7a4070b0'::uuid, 'ca'::public.profile_locale, 'salsa de soja'),
    ('d1840c2c-4094-4b16-b9a3-411e7a4070b0'::uuid, 'en'::public.profile_locale, 'soy sauce'),
    ('d1840c2c-4094-4b16-b9a3-411e7a4070b0'::uuid, 'es'::public.profile_locale, 'salsa de soja'),
    ('d6e06e97-f9bb-427c-a5b2-895966e9b2fb'::uuid, 'ca'::public.profile_locale, 'cacau en pols'),
    ('d6e06e97-f9bb-427c-a5b2-895966e9b2fb'::uuid, 'en'::public.profile_locale, 'cocoa powder'),
    ('d6e06e97-f9bb-427c-a5b2-895966e9b2fb'::uuid, 'es'::public.profile_locale, 'cacao en polvo'),
    ('d82a0f7d-d0b5-4517-b213-cf7c2d876ce0'::uuid, 'ca'::public.profile_locale, 'pomes'),
    ('d82a0f7d-d0b5-4517-b213-cf7c2d876ce0'::uuid, 'en'::public.profile_locale, 'apples'),
    ('d82a0f7d-d0b5-4517-b213-cf7c2d876ce0'::uuid, 'es'::public.profile_locale, 'manzanas'),
    ('db574d2e-dccc-4f3c-b355-ef97c14cdd28'::uuid, 'ca'::public.profile_locale, 'prosecco'),
    ('db574d2e-dccc-4f3c-b355-ef97c14cdd28'::uuid, 'en'::public.profile_locale, 'prosecco'),
    ('db574d2e-dccc-4f3c-b355-ef97c14cdd28'::uuid, 'es'::public.profile_locale, 'prosecco'),
    ('df9f4556-59a2-4563-bb92-719424dff0e8'::uuid, 'ca'::public.profile_locale, 'pa de massa mare'),
    ('df9f4556-59a2-4563-bb92-719424dff0e8'::uuid, 'en'::public.profile_locale, 'sourdough bread'),
    ('df9f4556-59a2-4563-bb92-719424dff0e8'::uuid, 'es'::public.profile_locale, 'pan de masa madre'),
    ('dfb2321c-d029-4f2d-aca0-377132da85e9'::uuid, 'ca'::public.profile_locale, 'llimes'),
    ('dfb2321c-d029-4f2d-aca0-377132da85e9'::uuid, 'en'::public.profile_locale, 'limes'),
    ('dfb2321c-d029-4f2d-aca0-377132da85e9'::uuid, 'es'::public.profile_locale, 'limas'),
    ('e293e5b7-600f-448f-9ef3-dcb815a4cb4a'::uuid, 'ca'::public.profile_locale, 'menta fresca'),
    ('e293e5b7-600f-448f-9ef3-dcb815a4cb4a'::uuid, 'en'::public.profile_locale, 'fresh mint'),
    ('e293e5b7-600f-448f-9ef3-dcb815a4cb4a'::uuid, 'es'::public.profile_locale, 'menta fresca'),
    ('e841d063-587d-436c-b4d3-4876fd5b645f'::uuid, 'ca'::public.profile_locale, 'nabius'),
    ('e841d063-587d-436c-b4d3-4876fd5b645f'::uuid, 'en'::public.profile_locale, 'blueberries'),
    ('e841d063-587d-436c-b4d3-4876fd5b645f'::uuid, 'es'::public.profile_locale, 'arándanos'),
    ('eb04fb7c-e608-4f67-855b-cdba6ad4e734'::uuid, 'ca'::public.profile_locale, 'alfàbrega'),
    ('eb04fb7c-e608-4f67-855b-cdba6ad4e734'::uuid, 'en'::public.profile_locale, 'basil'),
    ('eb04fb7c-e608-4f67-855b-cdba6ad4e734'::uuid, 'es'::public.profile_locale, 'albahaca');

  -- ── 1. Demo copies (compared against the template's CURRENT values) ───────
  update public.translations t
     set text = o.old_text
    from public.ingredients c
    join _old_tr o on c.id = public._demo_clone_id(c.group_id, o.id)
    join public.translations tt
      on tt.entity_type = 'ingredient' and tt.entity_id = o.id
     and tt.field = 'name' and tt.locale = o.locale
   where c.group_id <> v_template
     and t.entity_type = 'ingredient' and t.entity_id = c.id
     and t.field = 'name' and t.locale = o.locale
     and t.text = tt.text
     and t.text <> o.old_text;
  get diagnostics v_n = row_count; v_total := v_total + v_n;
  raise notice 'demo copies — translations restored: %', v_n;

  update public.ingredients c
     set name = o.old_name
    from _old_name o
    join public.ingredients tpl on tpl.id = o.id and tpl.group_id = v_template
   where c.group_id <> v_template
     and c.id = public._demo_clone_id(c.group_id, o.id)
     and c.name = tpl.name
     and c.name <> o.old_name;
  get diagnostics v_n = row_count; v_total := v_total + v_n;
  raise notice 'demo copies — ingredients restored: %', v_n;

  -- ── 2. The template itself ───────────────────────────────────────────────
  update public.translations t
     set text = o.old_text
    from _old_tr o
   where t.entity_type = 'ingredient' and t.entity_id = o.id
     and t.field = 'name' and t.locale = o.locale
     and t.text <> o.old_text;
  get diagnostics v_n = row_count; v_total := v_total + v_n;
  raise notice 'template — translations restored: %', v_n;

  update public.ingredients i
     set name = o.old_name
    from _old_name o
   where i.id = o.id and i.group_id = v_template and i.name <> o.old_name;
  get diagnostics v_n = row_count; v_total := v_total + v_n;
  raise notice 'template — ingredients restored: %', v_n;

  raise notice 'TOTAL rows restored: %', v_total;

  -- ── Fail closed: the template must match the snapshot exactly ────────────
  select (select count(*) from _old_name o join public.ingredients i on i.id = o.id
           where i.name <> o.old_name)
       + (select count(*) from _old_tr o join public.translations t
            on t.entity_type = 'ingredient' and t.entity_id = o.id
           and t.field = 'name' and t.locale = o.locale
           where t.text <> o.old_text)
    into v_left;
  if v_left > 0 then
    raise exception 'rollback incomplete: % template values differ from the snapshot', v_left;
  end if;
end;
$$;
