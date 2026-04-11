using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FreestyleCombo.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class RenameMotionToRevolution : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "AllowedMotions",
                table: "UserPreferences",
                newName: "AllowedRevolutions");

            migrationBuilder.RenameColumn(
                name: "Motion",
                table: "TrickSubmissions",
                newName: "Revolution");

            migrationBuilder.RenameColumn(
                name: "Motion",
                table: "Tricks",
                newName: "Revolution");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "AllowedRevolutions",
                table: "UserPreferences",
                newName: "AllowedMotions");

            migrationBuilder.RenameColumn(
                name: "Revolution",
                table: "TrickSubmissions",
                newName: "Motion");

            migrationBuilder.RenameColumn(
                name: "Revolution",
                table: "Tricks",
                newName: "Motion");
        }
    }
}
