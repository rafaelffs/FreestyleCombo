using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FreestyleCombo.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class ConvertPersonalReusableToUserRelation : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "UserPersonalReusableCombos",
                columns: table => new
                {
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    ComboId = table.Column<Guid>(type: "uuid", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserPersonalReusableCombos", x => new { x.UserId, x.ComboId });
                    table.ForeignKey(
                        name: "FK_UserPersonalReusableCombos_AspNetUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_UserPersonalReusableCombos_Combos_ComboId",
                        column: x => x.ComboId,
                        principalTable: "Combos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_UserPersonalReusableCombos_ComboId",
                table: "UserPersonalReusableCombos",
                column: "ComboId");

            // Preserve any existing owner-only personal-reusable flags as the
            // owner's own row in the new per-user table, before the column
            // that held them goes away.
            migrationBuilder.Sql(
                """
                INSERT INTO "UserPersonalReusableCombos" ("UserId", "ComboId", "CreatedAt")
                SELECT "OwnerId", "Id", now()
                FROM "Combos"
                WHERE "IsPersonalReusable" = true;
                """);

            migrationBuilder.DropColumn(
                name: "IsPersonalReusable",
                table: "Combos");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "UserPersonalReusableCombos");

            migrationBuilder.AddColumn<bool>(
                name: "IsPersonalReusable",
                table: "Combos",
                type: "boolean",
                nullable: false,
                defaultValue: false);
        }
    }
}
