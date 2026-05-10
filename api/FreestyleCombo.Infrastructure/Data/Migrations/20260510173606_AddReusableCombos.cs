using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FreestyleCombo.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddReusableCombos : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<Guid>(
                name: "TrickId",
                table: "ComboTricks",
                type: "uuid",
                nullable: true,
                oldClrType: typeof(Guid),
                oldType: "uuid");

            migrationBuilder.AddColumn<Guid>(
                name: "SubComboId",
                table: "ComboTricks",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsReusable",
                table: "Combos",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateIndex(
                name: "IX_ComboTricks_SubComboId",
                table: "ComboTricks",
                column: "SubComboId");

            migrationBuilder.AddCheckConstraint(
                name: "CK_ComboTrick_TrickOrSubCombo",
                table: "ComboTricks",
                sql: "(\"TrickId\" IS NOT NULL AND \"SubComboId\" IS NULL) OR (\"TrickId\" IS NULL AND \"SubComboId\" IS NOT NULL)");

            migrationBuilder.AddForeignKey(
                name: "FK_ComboTricks_Combos_SubComboId",
                table: "ComboTricks",
                column: "SubComboId",
                principalTable: "Combos",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_ComboTricks_Combos_SubComboId",
                table: "ComboTricks");

            migrationBuilder.DropIndex(
                name: "IX_ComboTricks_SubComboId",
                table: "ComboTricks");

            migrationBuilder.DropCheckConstraint(
                name: "CK_ComboTrick_TrickOrSubCombo",
                table: "ComboTricks");

            migrationBuilder.DropColumn(
                name: "SubComboId",
                table: "ComboTricks");

            migrationBuilder.DropColumn(
                name: "IsReusable",
                table: "Combos");

            migrationBuilder.AlterColumn<Guid>(
                name: "TrickId",
                table: "ComboTricks",
                type: "uuid",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"),
                oldClrType: typeof(Guid),
                oldType: "uuid",
                oldNullable: true);
        }
    }
}
