using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FreestyleCombo.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class RenameToAverageDifficulty : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "TotalDifficulty",
                table: "Combos");

            migrationBuilder.AddColumn<double>(
                name: "AverageDifficulty",
                table: "Combos",
                type: "double precision",
                nullable: false,
                defaultValue: 0.0);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "AverageDifficulty",
                table: "Combos");

            migrationBuilder.AddColumn<int>(
                name: "TotalDifficulty",
                table: "Combos",
                type: "integer",
                nullable: false,
                defaultValue: 0);
        }
    }
}
