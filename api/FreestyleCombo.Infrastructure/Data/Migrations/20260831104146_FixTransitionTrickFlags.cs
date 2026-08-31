using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FreestyleCombo.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class FixTransitionTrickFlags : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Data fix, not a schema change: transition tricks (e.g. "Combo") are
            // connectors with no foot/no-touch of their own, but before the app
            // enforced that, ComboTrick rows referencing a transition Trick could
            // end up with StrongFoot = false and/or NoTouch = true. Normalize
            // those back to the only valid state.
            migrationBuilder.Sql(
                """
                UPDATE "ComboTricks" ct
                SET "StrongFoot" = true,
                    "NoTouch" = false
                FROM "Tricks" t
                WHERE ct."TrickId" = t."Id"
                  AND t."IsTransition" = true
                  AND (ct."StrongFoot" = false OR ct."NoTouch" = true);
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Irreversible data fix — the original (incorrect) per-row flag
            // values weren't preserved, so there's nothing meaningful to restore.
        }
    }
}
