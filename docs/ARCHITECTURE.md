# Minecraft2 Architecture

## هدف
Minecraft2 یک موتور voxel مستقل و قابل توسعه است که APIهای اصلی موردنیاز بازی را داخل خود برنامه نگه می‌دارد. وابستگی به API بیرونی برای اجرای هسته بازی هدف نیست.

## لایه‌ها

1. **Core Runtime** — راه‌اندازی پوشه‌ها، تنظیمات، کش، لاگ و قابلیت‌ها.
2. **Voxel World** — chunk، block state، lighting، collision و hidden-face culling.
3. **Content Registries** — رجیستری یکتای block، item، entity، biome، recipe، sound و particle.
4. **Command Engine** — parser و dispatcher برای فرمان‌های `/` با syntax قابل توسعه.
5. **Pack System** — Resource Pack و Behavior Pack با manifest و dependency resolution.
6. **Mod Compatibility** — adapter برای metadata و قابلیت‌های Fabric/Forge؛ مود Java به‌صورت مستقیم داخل Godot اجرا نمی‌شود و باید به API داخلی ترجمه یا با adapter اجرا شود.
7. **Scripting API** — API داخلی شبیه مفهوم Server/Entity/World و event bus برای افزونه‌های Minecraft2.
8. **Networking** — client/server messages، world synchronization و نسخه‌بندی protocol.
9. **Persistence** — ذخیره world/chunks/player/config در `user://Minecraft2`.
10. **Mobile Input** — سه control scheme، remapping، touch actions و first/third person camera.

## مسیر دادهٔ کاربر

`user://Minecraft2/`

- `mods/` — ورودی مودها و adapterها
- `resource_packs/` — منابع گرافیکی/صوتی
- `behavior_packs/` — رفتار و script packها
- `worlds/` — دنیاها و chunk data
- `config/` — تنظیمات و capability state
- `cache/` — cache قابل بازسازی
- `logs/` — گزارش خطا و loader

Godot مسیر `user://` را در پروژه‌های export شده قابل نوشتن و مخصوص همان برنامه نگه می‌دارد؛ بنابراین برای دادهٔ کاربر مناسب است.

## قرارداد 16x16

هر texture پایهٔ voxel باید 16x16 باشد. Renderer می‌تواند mipmap/atlas داخلی داشته باشد، ولی منبع پایه برای block/item از قرارداد 16x16 پیروی می‌کند.

## خودگسترش امن

«خودش را بزرگ‌تر کند» در معماری Minecraft2 به معنی این است:

- capability missing → ایجاد stub داخلی و ثبت diagnostic
- registry extension → ثبت بدون تغییر هسته
- command extension → ثبت فرمان جدید
- pack extension → شناسایی بر اساس manifest
- mod dependency → dependency graph و compatibility report
- cache → بازسازی خودکار در صورت حذف یا خرابی

کد native یا JAR ناشناس به‌صورت پیش‌فرض مستقیم اجرا نمی‌شود. این باعث می‌شود یک extension خراب کل بازی را نابود نکند.

## منابع رسمی بررسی‌شده

- Minecraft Bedrock Command Reference: فرمان‌های `/help`, `/execute`, `/give`, `/fill`, `/setblock`, `/summon`, `/scoreboard`, `/tp` و دسته‌های مرتبط.
- Minecraft Creator Pack Manifest و Comprehensive Pack Contents: ساختار `manifest.json`، moduleها و packها.
- Minecraft Creator Script API: وابستگی نسخه‌ای ماژول‌های scripting و stable/beta tracks.
- Fabric Loader: `fabric.mod.json`, entrypoints, dependencies, mixins و `mods` directory.
- Forge: `mods.toml`, registry، lifecycle، dependency و networking.
- Godot 4.4 data paths: `user://` برای دادهٔ پایدار در export.
