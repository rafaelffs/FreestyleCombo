using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FreestyleCombo.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class RenameTotalDifficulty : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "AverageDifficulty",
                table: "Combos",
                newName: "TotalDifficulty");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "TotalDifficulty",
                table: "Combos",
                newName: "AverageDifficulty");
        }
    }
}
