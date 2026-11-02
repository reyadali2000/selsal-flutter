using System;
using System.IO;
using System.Text.RegularExpressions;

class Program
{
    static void Main()
    {
        string filePath = @""C:\Users\REYADH\source\repos\WadiAlAin\WadiAlAin.Api\Controllers\DynamicReportsController.cs"";
        string content = File.ReadAllText(filePath);
        
        string newEndpoints = @""
        [HttpGet(""""stats"""")]
        public async Task<ActionResult<ApiResponse<dynamic>>> GetStats([FromQuery] string timeframe = """"all"""", [FromQuery] int? branchId = null)
        {
            using var conn = _db.CreateConnection();
            var now = DateTime.UtcNow;
            string dateFilter = """";
            
            if (timeframe == """"today"""") dateFilter = $""""CONVERT(date, created_at) = '{now:yyyy-MM-dd}'"""";
            else if (timeframe == """"week"""") dateFilter = $""""CONVERT(date, created_at) >= '{now.AddDays(-7):yyyy-MM-dd}'"""";
            else if (timeframe == """"month"""") dateFilter = $""""created_at >= '{now:yyyy-MM-01}'"""";

            string branchFilter = branchId.HasValue && branchId.Value > 0 
                ? (dateFilter == """" """" ? """"WHERE (branch_id = @BranchId OR branch_id IS NULL)"""" : """" AND (branch_id = @BranchId OR branch_id IS NULL)"""")
                : """";
                
            string whereClause = dateFilter != """" """" ? $""""WHERE {dateFilter} {branchFilter}"""" : branchFilter;

            var totalReports = await conn.ExecuteScalarAsync<int>(""""SELECT COUNT(*) FROM dr_reports WHERE is_active = 1"""");
            var totalRecords = await conn.ExecuteScalarAsync<int>($""""SELECT COUNT(*) FROM dr_records {whereClause}"""", new { BranchId = branchId });
            
            string appWhere = whereClause == """" """" ? """"WHERE approval_status = 'Approved'"""" : $""""{whereClause} AND approval_status = 'Approved'"""";
            var approvedRecords = await conn.ExecuteScalarAsync<int>($""""SELECT COUNT(*) FROM dr_records {appWhere}"""", new { BranchId = branchId });

            string qmWhere = whereClause == """" """" ? """"WHERE approval_status = 'Pending_QM'"""" : $""""{whereClause} AND approval_status = 'Pending_QM'"""";
            var pendingQM = await conn.ExecuteScalarAsync<int>($""""SELECT COUNT(*) FROM dr_records {qmWhere}"""", new { BranchId = branchId });

            string gmWhere = whereClause == """" """" ? """"WHERE approval_status = 'Pending_GM'"""" : $""""{whereClause} AND approval_status = 'Pending_GM'"""";
            var pendingGM = await conn.ExecuteScalarAsync<int>($""""SELECT COUNT(*) FROM dr_records {gmWhere}"""", new { BranchId = branchId });

            string rejWhere = whereClause == """" """" ? """"WHERE approval_status = 'Rejected'"""" : $""""{whereClause} AND approval_status = 'Rejected'"""";
            var rejectedRecords = await conn.ExecuteScalarAsync<int>($""""SELECT COUNT(*) FROM dr_records {rejWhere}"""", new { BranchId = branchId });

            string cipWhere = whereClause == """" """" ? """"WHERE approval_status = 'Corrective_In_Progress'"""" : $""""{whereClause} AND approval_status = 'Corrective_In_Progress'"""";
            var correctiveInProgress = await conn.ExecuteScalarAsync<int>($""""SELECT COUNT(*) FROM dr_records {cipWhere}"""", new { BranchId = branchId });

            string gmdWhere = whereClause == """" """" ? """"WHERE approval_status = 'Pending_GM_Decision'"""" : $""""{whereClause} AND approval_status = 'Pending_GM_Decision'"""";
            var pendingGMDecision = await conn.ExecuteScalarAsync<int>($""""SELECT COUNT(*) FROM dr_records {gmdWhere}"""", new { BranchId = branchId });

            string compWhere = whereClause == """" """" ? """"WHERE is_compliant = 1"""" : $""""{whereClause} AND is_compliant = 1"""";
            var compliantRecords = await conn.ExecuteScalarAsync<int>($""""SELECT COUNT(*) FROM dr_records {compWhere}"""", new { BranchId = branchId });

            return Ok(ApiResponse<dynamic>.Ok(new {
                totalReports, totalRecords, approvedRecords, pendingQM, pendingGM, rejectedRecords,
                correctiveInProgress, pendingGMDecision, compliantRecords
            }));
        }

        [HttpGet(""""records/pending"""")]
        public async Task<ActionResult<ApiResponse<IEnumerable<dynamic>>>> GetPendingRecords([FromQuery] string roleStatus, [FromQuery] int? branchId = null)
        {
            using var conn = _db.CreateConnection();
            string sql = @""""
                SELECT r.id AS record_id, r.report_id, r.created_at, r.created_by, r.approval_status,
                       rep.name AS report_name
                FROM dr_records r
                INNER JOIN dr_reports rep ON r.report_id = rep.id
                WHERE r.approval_status = @RoleStatus
                  AND r.data_json NOT LIKE '%""""_source"""":""""legacy_adapter""""%'
            """";
            if (branchId.HasValue && branchId.Value > 0)
            {
                sql += branchId.Value == 1 ? """" AND (r.branch_id = 1 OR r.branch_id IS NULL)"""" : """" AND r.branch_id = @BranchId"""";
            }
            sql += """" ORDER BY r.created_at DESC"""";

            var records = await conn.QueryAsync(sql, new { RoleStatus = roleStatus, BranchId = branchId });
            return Ok(ApiResponse<IEnumerable<dynamic>>.Ok(records));
        }

        [HttpGet(""""records/corrective"""")]
        public async Task<ActionResult<ApiResponse<IEnumerable<dynamic>>>> GetCorrectiveActionRecords([FromQuery] int? branchId = null)
        {
            using var conn = _db.CreateConnection();
            string sql = @""""
                SELECT r.id AS record_id, r.report_id, r.created_at, r.created_by, r.approval_status,
                       r.rejection_reason, r.rejected_by, r.rejected_at,
                       r.rejection_category, r.severity_level, r.affected_products, r.immediate_action,
                       r.corrective_action, r.corrective_owner, r.corrective_due_date,
                       r.gm_decision, r.gm_decision_by, r.gm_decision_at, r.gm_decision_notes,
                       rep.name AS report_name
                FROM dr_records r
                INNER JOIN dr_reports rep ON r.report_id = rep.id
                WHERE r.approval_status IN ('Rejected', 'Corrective_In_Progress', 'Pending_GM_Decision', 'Rejected_By_GM')
                  AND r.data_json NOT LIKE '%""""_source"""":""""legacy_adapter""""%'
            """";
            if (branchId.HasValue && branchId.Value > 0)
            {
                sql += branchId.Value == 1 ? """" AND (r.branch_id = 1 OR r.branch_id IS NULL)"""" : """" AND r.branch_id = @BranchId"""";
            }
            sql += @"""" ORDER BY CASE r.severity_level WHEN N'حرجة' THEN 4 WHEN N'عالية' THEN 3 WHEN N'متوسطة' THEN 2 WHEN N'منخ� ضة' THEN 1 ELSE 0 END DESC, r.created_at DESC"""";

            var records = await conn.QueryAsync(sql, new { BranchId = branchId });
            return Ok(ApiResponse<IEnumerable<dynamic>>.Ok(records));
        }
"";

        content = content.Replace(""[HttpGet(\""records/{id}\"")]"", newEndpoints + ""\n\n        [HttpGet(\""records/{id}\"")]"");
        File.WriteAllText(filePath, content);
    }
}
