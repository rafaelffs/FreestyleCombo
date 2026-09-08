using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FreestyleCombo.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class MakeStrongFootPercentageOptional : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<int>(
                name: "StrongFootPercentage",
                table: "UserPreferences",
                type: "integer",
                nullable: true,
                oldClrType: typeof(int),
                oldType: "integer");
        }

        /// <inheritdoc />
        // NOTE: If any UserPreferences rows have actually been saved with
        // StrongFootPercentage null (the whole point of this migration), this
        // Down() will fail with a NOT NULL constraint violation —
        // AlterColumn's defaultValue only applies to future inserts, it
        // doesn't backfill existing NULLs. Backfill manually (e.g. `UPDATE
        // "UserPreferences" SET "StrongFootPercentage" = 60 WHERE
        // "StrongFootPercentage" IS NULL`) before rolling back.
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<int>(
                name: "StrongFootPercentage",
                table: "UserPreferences",
                type: "integer",
                nullable: false,
                defaultValue: 0,
                oldClrType: typeof(int),
                oldType: "integer",
                oldNullable: true);
        }
    }
}
