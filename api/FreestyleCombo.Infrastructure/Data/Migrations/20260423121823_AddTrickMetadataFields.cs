using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FreestyleCombo.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddTrickMetadataFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "CreatedBy",
                table: "Tricks",
                type: "character varying(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<DateOnly>(
                name: "DateCreated",
                table: "Tricks",
                type: "date",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Notes",
                table: "Tricks",
                type: "character varying(500)",
                maxLength: 500,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "CreatedBy",
                table: "Tricks");

            migrationBuilder.DropColumn(
                name: "DateCreated",
                table: "Tricks");

            migrationBuilder.DropColumn(
                name: "Notes",
                table: "Tricks");
        }
    }
}
