using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FreestyleCombo.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddCreatedAtToAppUser : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Existing rows predate this column and have no recoverable real
            // registration date — backfill them to the migration-apply time
            // (via the DB's own NOW(), evaluated once for the whole statement)
            // rather than DateTime.MinValue, which would show as "0001-01-01"
            // in the admin UI. New rows always set this explicitly in code
            // (RegisterHandler/ExternalSignInHandler), so this default only
            // ever applies to this one backfill.
            migrationBuilder.AddColumn<DateTime>(
                name: "CreatedAt",
                table: "AspNetUsers",
                type: "timestamp with time zone",
                nullable: false,
                defaultValueSql: "now()");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "CreatedAt",
                table: "AspNetUsers");
        }
    }
}
