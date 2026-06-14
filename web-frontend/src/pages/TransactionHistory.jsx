import {
  ArrowDownward as ArrowDownwardIcon,
  ArrowUpward as ArrowUpwardIcon,
  FilterList as FilterListIcon,
} from "@mui/icons-material";
import {
  Avatar,
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  CircularProgress,
  Container,
  FormControl,
  Grid,
  InputLabel,
  MenuItem,
  Paper,
  Select,
  Typography,
} from "@mui/material";
import { useEffect, useState } from "react";
import {
  AnimatedElement,
  StaggeredList,
} from "../components/AnimationComponents";
import { simulateApiCall } from "../services/api";

const MOCK_TRANSACTIONS = [
  {
    id: "tx1",
    type: "incoming",
    amount: 1250.0,
    date: "2025-04-10T14:32:21",
    description: "Salary payment",
    sender: "Acme Corp",
    status: "completed",
  },
  {
    id: "tx2",
    type: "outgoing",
    amount: 42.5,
    date: "2025-04-09T09:15:00",
    description: "Coffee shop",
    recipient: "Starbucks",
    status: "completed",
  },
  {
    id: "tx3",
    type: "outgoing",
    amount: 850.0,
    date: "2025-04-05T18:22:10",
    description: "Rent payment",
    recipient: "Property Management Inc",
    status: "completed",
  },
  {
    id: "tx4",
    type: "incoming",
    amount: 125.0,
    date: "2025-04-03T12:05:45",
    description: "Refund",
    sender: "Amazon",
    status: "completed",
  },
  {
    id: "tx5",
    type: "outgoing",
    amount: 35.99,
    date: "2025-04-01T20:15:30",
    description: "Subscription",
    recipient: "Netflix",
    status: "completed",
  },
  {
    id: "tx6",
    type: "outgoing",
    amount: 200.0,
    date: "2025-03-28T11:00:00",
    description: "Transfer to savings",
    recipient: "Chase Savings",
    status: "pending",
  },
  {
    id: "tx7",
    type: "incoming",
    amount: 75.0,
    date: "2025-03-25T16:45:00",
    description: "Freelance payment",
    sender: "Client XYZ",
    status: "completed",
  },
];

const TransactionHistory = () => {
  const [transactions, setTransactions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState("all");
  const [error, setError] = useState("");

  useEffect(() => {
    const fetchTransactions = async () => {
      setLoading(true);
      setError("");
      try {
        const response = await simulateApiCall(
          { transactions: MOCK_TRANSACTIONS },
          800,
        );
        setTransactions(response.data.transactions);
      } catch (err) {
        console.error("Failed to load transactions:", err);
        setError("Failed to load transactions. Please try again.");
      } finally {
        setLoading(false);
      }
    };

    fetchTransactions();
  }, []);

  const formatCurrency = (amount) =>
    new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: "USD",
    }).format(amount);

  const formatDate = (dateString) =>
    new Intl.DateTimeFormat("en-US", {
      month: "short",
      day: "numeric",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    }).format(new Date(dateString));

  const filteredTransactions = transactions.filter((tx) => {
    if (filter === "all") return true;
    if (filter === "incoming") return tx.type === "incoming";
    if (filter === "outgoing") return tx.type === "outgoing";
    if (filter === "pending") return tx.status === "pending";
    return true;
  });

  const totalIncoming = transactions
    .filter((tx) => tx.type === "incoming" && tx.status === "completed")
    .reduce((sum, tx) => sum + tx.amount, 0);

  const totalOutgoing = transactions
    .filter((tx) => tx.type === "outgoing" && tx.status === "completed")
    .reduce((sum, tx) => sum + tx.amount, 0);

  return (
    <Container maxWidth="lg" sx={{ py: 4 }}>
      <AnimatedElement>
        <Typography
          variant="h4"
          component="h1"
          sx={{ mb: 4, fontWeight: "bold" }}
        >
          Transaction History
        </Typography>
      </AnimatedElement>

      <Grid container spacing={3} sx={{ mb: 4 }}>
        <Grid item xs={12} sm={6} md={4}>
          <AnimatedElement animation="fadeInUp" delay={0.1}>
            <Paper
              elevation={2}
              sx={{
                p: 3,
                borderRadius: 4,
                background: "linear-gradient(135deg, #2e7d32 0%, #1b5e20 100%)",
                color: "white",
              }}
            >
              <Typography variant="body2" sx={{ opacity: 0.85, mb: 1 }}>
                Total Received
              </Typography>
              <Typography variant="h5" sx={{ fontWeight: "bold" }}>
                {formatCurrency(totalIncoming)}
              </Typography>
            </Paper>
          </AnimatedElement>
        </Grid>
        <Grid item xs={12} sm={6} md={4}>
          <AnimatedElement animation="fadeInUp" delay={0.2}>
            <Paper
              elevation={2}
              sx={{
                p: 3,
                borderRadius: 4,
                background: "linear-gradient(135deg, #c62828 0%, #b71c1c 100%)",
                color: "white",
              }}
            >
              <Typography variant="body2" sx={{ opacity: 0.85, mb: 1 }}>
                Total Sent
              </Typography>
              <Typography variant="h5" sx={{ fontWeight: "bold" }}>
                {formatCurrency(totalOutgoing)}
              </Typography>
            </Paper>
          </AnimatedElement>
        </Grid>
        <Grid item xs={12} sm={6} md={4}>
          <AnimatedElement animation="fadeInUp" delay={0.3}>
            <Paper
              elevation={2}
              sx={{
                p: 3,
                borderRadius: 4,
                background: "linear-gradient(135deg, #1565c0 0%, #0d47a1 100%)",
                color: "white",
              }}
            >
              <Typography variant="body2" sx={{ opacity: 0.85, mb: 1 }}>
                Net Flow
              </Typography>
              <Typography variant="h5" sx={{ fontWeight: "bold" }}>
                {formatCurrency(totalIncoming - totalOutgoing)}
              </Typography>
            </Paper>
          </AnimatedElement>
        </Grid>
      </Grid>

      <AnimatedElement animation="fadeInUp" delay={0.2}>
        <Paper elevation={2} sx={{ p: 3, borderRadius: 4 }}>
          <Box
            sx={{
              display: "flex",
              justifyContent: "space-between",
              alignItems: "center",
              mb: 3,
              flexWrap: "wrap",
              gap: 2,
            }}
          >
            <Typography variant="h6" sx={{ fontWeight: "medium" }}>
              All Transactions
            </Typography>
            <Box sx={{ display: "flex", alignItems: "center", gap: 1 }}>
              <FilterListIcon color="action" />
              <FormControl size="small" sx={{ minWidth: 140 }}>
                <InputLabel id="transaction-filter-label">Filter</InputLabel>
                <Select
                  labelId="transaction-filter-label"
                  id="transaction-filter"
                  value={filter}
                  label="Filter"
                  onChange={(e) => setFilter(e.target.value)}
                >
                  <MenuItem value="all">All</MenuItem>
                  <MenuItem value="incoming">Incoming</MenuItem>
                  <MenuItem value="outgoing">Outgoing</MenuItem>
                  <MenuItem value="pending">Pending</MenuItem>
                </Select>
              </FormControl>
            </Box>
          </Box>

          {loading ? (
            <Box sx={{ display: "flex", justifyContent: "center", py: 6 }}>
              <CircularProgress />
            </Box>
          ) : error ? (
            <Box sx={{ textAlign: "center", py: 6 }}>
              <Typography color="error">{error}</Typography>
              <Button sx={{ mt: 2 }} onClick={() => window.location.reload()}>
                Retry
              </Button>
            </Box>
          ) : filteredTransactions.length === 0 ? (
            <Box sx={{ textAlign: "center", py: 6 }}>
              <Typography color="text.secondary">
                No transactions found
              </Typography>
            </Box>
          ) : (
            <StaggeredList staggerDelay={0.05}>
              {filteredTransactions.map((transaction) => (
                <Card
                  key={transaction.id}
                  elevation={0}
                  sx={{
                    mb: 2,
                    borderRadius: 2,
                    border: "1px solid",
                    borderColor: "divider",
                    transition: "transform 0.2s, box-shadow 0.2s",
                    "&:hover": {
                      transform: "translateY(-2px)",
                      boxShadow: 2,
                    },
                  }}
                >
                  <CardContent sx={{ p: 2, "&:last-child": { pb: 2 } }}>
                    <Grid container alignItems="center" spacing={2}>
                      <Grid item>
                        <Avatar
                          sx={{
                            bgcolor:
                              transaction.type === "incoming"
                                ? "success.light"
                                : "error.light",
                            width: 40,
                            height: 40,
                          }}
                        >
                          {transaction.type === "incoming" ? (
                            <ArrowDownwardIcon />
                          ) : (
                            <ArrowUpwardIcon />
                          )}
                        </Avatar>
                      </Grid>
                      <Grid item xs>
                        <Typography
                          variant="subtitle1"
                          sx={{ fontWeight: "medium" }}
                        >
                          {transaction.description}
                        </Typography>
                        <Typography variant="body2" color="text.secondary">
                          {transaction.type === "incoming"
                            ? `From: ${transaction.sender}`
                            : `To: ${transaction.recipient}`}
                        </Typography>
                        <Typography variant="caption" color="text.secondary">
                          {formatDate(transaction.date)}
                        </Typography>
                      </Grid>
                      <Grid item sx={{ textAlign: "right" }}>
                        <Typography
                          variant="subtitle1"
                          sx={{
                            fontWeight: "bold",
                            color:
                              transaction.type === "incoming"
                                ? "success.main"
                                : "error.main",
                          }}
                        >
                          {transaction.type === "incoming" ? "+" : "-"}
                          {formatCurrency(transaction.amount)}
                        </Typography>
                        <Chip
                          label={transaction.status}
                          size="small"
                          color={
                            transaction.status === "completed"
                              ? "success"
                              : "warning"
                          }
                          sx={{ mt: 0.5 }}
                        />
                      </Grid>
                    </Grid>
                  </CardContent>
                </Card>
              ))}
            </StaggeredList>
          )}
        </Paper>
      </AnimatedElement>
    </Container>
  );
};

export default TransactionHistory;
