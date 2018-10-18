/**
 * Copyright (c) 2011-2017 libbitcoin developers (see AUTHORS)
 *
 * This file is part of libbitcoin.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
#ifndef LIBBITCOIN_SERVER_BLOCKCHAIN_HPP
#define LIBBITCOIN_SERVER_BLOCKCHAIN_HPP

#include <cstddef>
#include <cstdint>
#include <bitcoin/blockchain.hpp>
#include <bitcoin/server/define.hpp>
#include <bitcoin/server/messages/message.hpp>
#include <bitcoin/server/server_node.hpp>

namespace libbitcoin {
namespace server {

/// Blockchain interface.
/// These queries results do NOT include transaction pool information.
/// Class and method names are published and mapped to the zeromq interface.
class BCS_API blockchain
{
public:
    /// Fetch the blockchain history of a payment address.
    static void fetch_history4(server_node& node,
        const message& request, send_handler handler);

    /// Fetch a transaction from the blockchain by its hash.
    static void fetch_transaction(server_node& node,
        const message& request, send_handler handler);

    /// Fetch a transaction with witness from the blockchain by its hash.
    static void fetch_transaction2(server_node& node,
        const message& request, send_handler handler);

    /// Fetch the current height of the blockchain.
    static void fetch_last_height(server_node& node,
        const message& request, send_handler handler);

    /// Fetch a block by hash or height (conditional serialization).
    static void fetch_block(server_node& node,
        const message& request, send_handler handler);

    /// Fetch a block header by hash or height (conditional serialization).
    static void fetch_block_header(server_node& node,
        const message& request, send_handler handler);

    /// Fetch tx hashes of block by hash or height (conditional serialization).
    static void fetch_block_transaction_hashes(server_node& node,
        const message& request, send_handler handler);

    /// Fetch the block index of a transaction and the height of its block.
    static void fetch_transaction_index(server_node& node,
        const message& request, send_handler handler);

    /// Fetch the inpoint which is spent by the specified output.
    static void fetch_spend(server_node& node,
        const message& request, send_handler handler);

    /// Fetch the height of a block by its hash.
    static void fetch_block_height(server_node& node,
        const message& request, send_handler handler);

    /// Fetch the history of a stealth address by its prefix filter.
    static void fetch_stealth2(server_node& node,
        const message& request, send_handler handler);

    /// Fetch the transactions of a stealth address by its prefix filter.
    static void fetch_stealth_transaction_hashes(server_node& node,
        const message& request, send_handler handler);

    /// Save to blockchain and announce to all connected peers.
    static void broadcast(server_node& node, const message& request,
        send_handler handler);

    /// Validate a block against the blockchain.
    static void validate(server_node& node, const message& request,
        send_handler handler);

private:
    static void history_fetched(const code& ec,
        const chain::payment_record::list& payments, const message& request,
        send_handler handler);

    static void transaction_fetched(const code& ec, transaction_const_ptr tx,
        size_t, size_t, const message& request, send_handler handler);

    static void last_height_fetched(const code& ec, size_t last_height,
        const message& request, send_handler handler);

    static void fetch_block_by_hash(server_node& node,
        const message& request, send_handler handler);

    static void fetch_block_by_height(server_node& node,
        const message& request, send_handler handler);

    static void fetch_block_header_by_hash(server_node& node,
        const message& request, send_handler handler);

    static void fetch_block_header_by_height(server_node& node,
        const message& request, send_handler handler);

    static void block_fetched(const code& ec,
        block_const_ptr header, const message& request,
        send_handler handler);

    static void block_header_fetched(const code& ec,
        header_const_ptr header, const message& request,
        send_handler handler);

    static void fetch_block_transaction_hashes_by_hash(server_node& node,
        const message& request, send_handler handler);

    static void fetch_block_transaction_hashes_by_height(server_node& node,
        const message& request, send_handler handler);

    static void merkle_block_fetched(const code& ec, merkle_block_ptr block,
        size_t height, const message& request, send_handler handler);

    static void transaction_index_fetched(const code& ec,
        size_t tx_position, size_t block_height, const message& request,
        send_handler handler);

    static void spend_fetched(const code& ec,
        const chain::input_point& inpoint, const message& request,
        send_handler handler);

    static void block_height_fetched(const code& ec, size_t block_height,
        const message& request, send_handler handler);

    static void stealth_fetched(const code& ec,
        const chain::stealth_record::list& stealth,
        const message& request, send_handler handler);

    static void stealth_transaction_hashes_fetched(const code& ec,
        const chain::stealth_record::list& stealth, const message& request,
        send_handler handler);

    static void handle_broadcast(const code& ec, const message& request,
        send_handler handler);

    static void handle_validated(const code& ec, const message& request,
        send_handler handler);
};

} // namespace server
} // namespace libbitcoin

#endif
