using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FreestyleCombo.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddComboVisibility : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "Visibility",
                table: "Combos",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            // Migrate existing data: public combos → Visibility = 2 (Public)
            migrationBuilder.Sql(@"UPDATE ""Combos"" SET ""Visibility"" = 2 WHERE ""IsPublic"" = true");

            migrationBuilder.DropColumn(
                name: "IsPublic",
                table: "Combos");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Visibility",
                table: "Combos");

            migrationBuilder.AddColumn<bool>(
                name: "IsPublic",
                table: "Combos",
                type: "boolean",
                nullable: false,
                defaultValue: false);
        }
    }
}
